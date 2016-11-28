const {
  IMAPConnection,
  IMAPErrors,
  PromiseUtils,
} = require('isomorphic-core');
const LocalDatabaseConnector = require('../shared/local-database-connector')
const {
  jsonError,
} = require('./sync-utils')

const FetchFolderList = require('./imap/fetch-folder-list')
const FetchMessagesInFolder = require('./imap/fetch-messages-in-folder')
const SyncbackTaskFactory = require('./syncback-task-factory')


class SyncWorker {
  constructor(account, db, onExpired) {
    this._db = db;
    this._conn = null;
    this._account = account;
    this._startTime = Date.now();
    this._lastSyncTime = null;
    this._onExpired = onExpired;
    this._logger = global.Logger.forAccount(account)

    this._destroyed = false;
    this._syncTimer = setTimeout(() => {
      this.syncNow({reason: 'Initial'});
    }, 0);
  }

  cleanup() {
    clearTimeout(this._syncTimer);
    this._syncTimer = null;
    this._destroyed = true;
    this.closeConnection()
  }

  closeConnection() {
    if (this._conn) {
      this._conn.end();
    }
  }

  _onConnectionIdleUpdate() {
    this.syncNow({reason: 'IMAP IDLE Fired'});
  }

  _getAccount() {
    return LocalDatabaseConnector.forShared().then(({Account}) =>
      Account.find({where: {id: this._account.id}})
    );
  }

  _getIdleFolder() {
    return this._db.Folder.find({where: {role: ['all', 'inbox']}})
  }

  ensureConnection() {
    if (this._conn) {
      return this._conn.connect();
    }
    const settings = this._account.connectionSettings;
    const credentials = this._account.decryptedCredentials();

    if (!settings || !settings.imap_host) {
      return Promise.reject(new Error("ensureConnection: There are no IMAP connection settings for this account."))
    }
    if (!credentials) {
      return Promise.reject(new Error("ensureConnection: There are no IMAP connection credentials for this account."))
    }

    const conn = new IMAPConnection({
      db: this._db,
      settings: Object.assign({}, settings, credentials),
      logger: this._logger,
    });

    conn.on('mail', () => {
      this._onConnectionIdleUpdate();
    })
    conn.on('update', () => {
      this._onConnectionIdleUpdate();
    })
    conn.on('queue-empty', () => {
    });

    this._conn = conn;
    return this._conn.connect();
  }

  syncbackMessageActions() {
    const {SyncbackRequest} = this._db;
    const where = {where: {status: "NEW"}, limit: 100};

    const tasks = SyncbackRequest.findAll(where).map((req) =>
      SyncbackTaskFactory.create(this._account, req)
    );

    return PromiseUtils.each(tasks, this.runSyncbackTask.bind(this));
  }

  runSyncbackTask(task) {
    const syncbackRequest = task.syncbackRequestObject()
    return this._conn.runOperation(task)
    .then(() => {
      syncbackRequest.status = "SUCCEEDED"
    })
    .catch((error) => {
      syncbackRequest.error = error
      syncbackRequest.status = "FAILED"
      this._logger.error(syncbackRequest.toJSON(), `${task.description()} failed`)
    })
    .finally(() => syncbackRequest.save())
  }

  syncMessagesInAllFolders() {
    const {Folder} = this._db;
    const {folderSyncOptions} = this._account.syncPolicy;

    return Folder.findAll().then((folders) => {
      const priority = ['inbox', 'all', 'drafts', 'sent', 'spam', 'trash'].reverse();
      const foldersSorted = folders.sort((a, b) =>
        (priority.indexOf(a.role) - priority.indexOf(b.role)) * -1
      )

      return Promise.all(foldersSorted.map((cat) =>
        this._conn.runOperation(new FetchMessagesInFolder(cat, folderSyncOptions, this._logger))
      ))
    });
  }

  syncNow({reason} = {}) {
    const syncInProgress = (this._syncTimer === null);
    if (syncInProgress) {
      return;
    }

    clearTimeout(this._syncTimer);
    this._syncTimer = null;

    this._account.reload().then(() => {
      console.log(this._account)
      if (this._account.errored()) {
        this._logger.error(`SyncWorker: Account is in error state - Retrying sync\n${this._account.syncError.message}`, this._account.syncError.stack.join('\n'))
      }
      this._logger.info({reason}, `SyncWorker: Account sync started`)

      return this._account.update({syncError: null})
      .then(() => this.ensureConnection())
      .then(() => this.syncbackMessageActions())
      .then(() => this._conn.runOperation(new FetchFolderList(this._account.provider, this._logger)))
      .then(() => this.syncMessagesInAllFolders())
      .then(() => this.onSyncDidComplete())
      .catch((error) => this.onSyncError(error))
    })
    .finally(() => {
      this._lastSyncTime = Date.now()
      this.scheduleNextSync()
    })
  }

  onSyncError(error) {
    this.closeConnection()

    this._logger.error(error, `SyncWorker: Error while syncing account`)

    // Continue to retry if it was a network error
    if (error instanceof IMAPErrors.RetryableError) {
      return Promise.resolve()
    }

    this._account.syncError = jsonError(error)
    return this._account.save()
  }

  onSyncDidComplete() {
    const now = Date.now();

    // Save metrics to the account object
    if (!this._account.firstSyncCompletion) {
      this._account.firstSyncCompletion = now;
    }

    const syncGraphTimeLength = 60 * 30; // 30 minutes, should be the same as SyncGraph.config.timeLength
    let lastSyncCompletions = [].concat(this._account.lastSyncCompletions)
    lastSyncCompletions = [now, ...lastSyncCompletions]
    while (now - lastSyncCompletions[lastSyncCompletions.length - 1] > 1000 * syncGraphTimeLength) {
      lastSyncCompletions.pop();
    }

    this._logger.info('Syncworker: Completed sync cycle')
    this._account.lastSyncCompletions = lastSyncCompletions
    this._account.save()

    // Start idling on the inbox
    return this._getIdleFolder()
    .then((idleFolder) => this._conn.openBox(idleFolder.name))
    .then(() => this._logger.info('SyncWorker: Idling on inbox folder'))
  }

  scheduleNextSync() {
    const {intervals} = this._account.syncPolicy;
    const {Folder} = this._db;

    return Folder.findAll().then((folders) => {
      const moreToSync = folders.some((f) =>
        f.syncState.fetchedmax < f.syncState.uidnext || f.syncState.fetchedmin > 1
      )

      const target = this._lastSyncTime + (moreToSync ? 1 : intervals.active);

      this._logger.info(`SyncWorker: Scheduling next sync iteration for ${target - Date.now()}ms}`)

      this._syncTimer = setTimeout(() => {
        this.syncNow({reason: 'Scheduled'});
      }, target - Date.now());
    });
  }
}

module.exports = SyncWorker;
