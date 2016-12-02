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
const SyncMetricsReporter = require('./sync-metrics-reporter');


class SyncWorker {
  constructor(account, db, parentManager) {
    this._db = db;
    this._manager = parentManager;
    this._conn = null;
    this._account = account;
    this._startTime = Date.now();
    this._lastSyncTime = null;
    this._logger = global.Logger.forAccount(account)

    this._destroyed = false;
    this._syncTimer = setTimeout(() => {
      this.syncNow({reason: 'Initial'});
    }, 0);

    // setup metrics collection. We do this in an isolated way by hooking onto
    // the database, because otherwise things get /crazy/ messy and I don't like
    // having counters and garbage everywhere.
    if (!account.firstSyncCompletion) {
      this._logger.info("This is initial sync. Setting up metrics collection!");

      let seen = 0;
      db.Thread.addHook('afterCreate', 'metricsCollection', () => {
        if (seen === 0) {
          SyncMetricsReporter.reportEvent({
            type: 'imap',
            emailAddress: account.emailAddress,
            msecToFirstThread: (Date.now() - new Date(account.createdAt).getTime()),
          })
        }
        if (seen === 500) {
          SyncMetricsReporter.reportEvent({
            type: 'imap',
            emailAddress: account.emailAddress,
            msecToFirst500Threads: (Date.now() - new Date(account.createdAt).getTime()),
          })
        }

        if (seen > 500) {
          db.Thread.removeHook('afterCreate', 'metricsCollection')
        }
        seen += 1;
      });
    }
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

  async _getAccount() {
    const {Account} = await LocalDatabaseConnector.forShared()
    Account.find({where: {id: this._account.id}})
  }

  _getIdleFolder() {
    return this._db.Folder.find({where: {role: ['all', 'inbox']}})
  }

  async ensureConnection() {
    if (this._conn) {
      return await this._conn.connect();
    }
    const settings = this._account.connectionSettings;
    const credentials = this._account.decryptedCredentials();

    if (!settings || !settings.imap_host) {
      throw new Error("ensureConnection: There are no IMAP connection settings for this account.");
    }
    if (!credentials) {
      throw new Error("ensureConnection: There are no IMAP connection credentials for this account.");
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
    return await this._conn.connect();
  }

  async syncbackMessageActions() {
    const {SyncbackRequest} = this._db;
    const where = {where: {status: "NEW"}, limit: 100};

    const tasks = (await SyncbackRequest.findAll(where)).map((req) =>
      SyncbackTaskFactory.create(this._account, req)
    );

    return PromiseUtils.each(tasks, this.runSyncbackTask.bind(this));
  }

  async runSyncbackTask(task) {
    const syncbackRequest = task.syncbackRequestObject();
    try {
      await this._conn.runOperation(task);
      syncbackRequest.status = "SUCCEEDED";
    } catch (error) {
      syncbackRequest.error = error;
      syncbackRequest.status = "FAILED";
      this._logger.error(syncbackRequest.toJSON(), `${task.description()} failed`);
    } finally {
      await syncbackRequest.save();
    }
  }

  async syncMessagesInAllFolders() {
    const {Folder} = this._db;
    const {folderSyncOptions} = this._account.syncPolicy;

    const folders = await Folder.findAll();
    const priority = ['inbox', 'all', 'drafts', 'sent', 'spam', 'trash'].reverse();
    const foldersSorted = folders.sort((a, b) =>
      (priority.indexOf(a.role) - priority.indexOf(b.role)) * -1
    )

    return await Promise.all(foldersSorted.map((cat) =>
      this._conn.runOperation(new FetchMessagesInFolder(cat, folderSyncOptions, this._logger))
    ))
  }

  async syncNow({reason} = {}) {
    const syncInProgress = (this._syncTimer === null);
    if (syncInProgress) {
      return;
    }

    clearTimeout(this._syncTimer);
    this._syncTimer = null;

    try {
      await this._account.reload();
    } catch (err) {
      this._logger.error({err}, `SyncWorker: Account could not be loaded. Sync worker will exit.`)
      this._manager.removeWorkerForAccountId(this._account.id);
      return;
    }

    this._logger.info({reason}, `SyncWorker: Account sync started`)

    try {
      await this._account.update({syncError: null});
      await this.ensureConnection();
      await this.syncbackMessageActions();
      await this._conn.runOperation(new FetchFolderList(this._account.provider, this._logger));
      await this.syncMessagesInAllFolders();
      await this.onSyncDidComplete();
    } catch (error) {
      this.onSyncError(error);
    } finally {
      this._lastSyncTime = Date.now()
      this.scheduleNextSync()
    }
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

  async onSyncDidComplete() {
    const now = Date.now();

    // Save metrics to the account object
    if (!this._account.firstSyncCompletion) {
      this._account.firstSyncCompletion = now;
    }

    const syncGraphTimeLength = 60 * 30; // 30 minutes, should be the same as SyncGraph.config.timeLength
    let lastSyncCompletions = [].concat(this._account.lastSyncCompletions);
    lastSyncCompletions = [now, ...lastSyncCompletions];
    while (now - lastSyncCompletions[lastSyncCompletions.length - 1] > 1000 * syncGraphTimeLength) {
      lastSyncCompletions.pop();
    }

    this._logger.info('Syncworker: Completed sync cycle');
    this._account.lastSyncCompletions = lastSyncCompletions;
    this._account.save();

    // Start idling on the inbox
    const idleFolder = await this._getIdleFolder();
    await this._conn.openBox(idleFolder.name);
    this._logger.info('SyncWorker: Idling on inbox folder');
  }

  async scheduleNextSync() {
    const {intervals} = this._account.syncPolicy;
    const {Folder} = this._db;

    const folders = await Folder.findAll();
    const moreToSync = folders.some((f) =>
      f.syncState.fetchedmax < f.syncState.uidnext || f.syncState.fetchedmin > 1
    )

    const target = this._lastSyncTime + (moreToSync ? 1 : intervals.active);

    this._logger.info(`SyncWorker: Scheduling next sync iteration for ${target - Date.now()}ms`)

    this._syncTimer = setTimeout(() => {
      this.syncNow({reason: 'Scheduled'});
    }, target - Date.now());
  }
}

module.exports = SyncWorker;
