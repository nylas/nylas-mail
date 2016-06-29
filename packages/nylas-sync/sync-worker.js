const {
  SchedulerUtils,
  IMAPConnection,
  PubsubConnector,
  DatabaseConnector,
  MessageTypes,
} = require('nylas-core');

const FetchCategoryList = require('./imap/fetch-category-list')
const FetchMessagesInCategory = require('./imap/fetch-messages-in-category')
const SyncbackTaskFactory = require('./syncback-task-factory')


class SyncWorker {
  constructor(account, db) {
    this._db = db;
    this._conn = null;
    this._account = account;
    this._lastSyncTime = null;

    this._syncTimer = null;
    this._expirationTimer = null;
    this._destroyed = false;

    this.syncNow();

    this._onMessage = this._onMessage.bind(this);
    this._listener = PubsubConnector.observe(account.id).subscribe(this._onMessage)
  }

  cleanup() {
    this._destroyed = true;
    this._listener.dispose();
    this.closeConnection()
  }

  closeConnection() {
    this._conn.end();
    this._conn = null
  }

  _onMessage(msg) {
    const {type} = JSON.parse(msg);
    switch (type) {
      case MessageTypes.ACCOUNT_UPDATED:
        this._onAccountUpdated(); break;
      case MessageTypes.SYNCBACK_REQUESTED:
        this.syncNow(); break;
      default:
        throw new Error(`Invalid message: ${msg}`)
    }
  }

  _onAccountUpdated() {
    console.log("SyncWorker: Detected change to account. Reloading and syncing now.");
    this._getAccount().then((account) => {
      this._account = account;
      this.syncNow();
    })
  }

  _getAccount() {
    return DatabaseConnector.forShared().then(({Account}) =>
      Account.find({where: {id: this._account.id}})
    );
  }

  onSyncDidComplete() {
    const {afterSync} = this._account.syncPolicy;

    if (afterSync === 'idle') {
      return this.getInboxCategory()
      .then((inboxCategory) => this._conn.openBox(inboxCategory.name))
      .then(() => console.log('SyncWorker: - Idling on inbox category'))
      .catch((error) => {
        console.error('SyncWorker: - Unhandled error while attempting to idle on Inbox after sync: ', error)
        this.closeConnection()
      })
    }

    if (afterSync === 'close') {
      console.log('SyncWorker: - Closing connection');
      this.closeConnection()
      return Promise.resolve()
    }

    throw new Error(`SyncWorker.onSyncDidComplete: Unknown afterSync behavior: ${afterSync}. Closing connection`)
  }

  onConnectionIdleUpdate() {
    this.syncNow();
  }

  getInboxCategory() {
    return this._db.Category.find({where: {role: 'inbox'}})
  }

  ensureConnection() {
    if (this._conn) {
      return this._conn.connect();
    }
    const settings = this._account.connectionSettings;
    const credentials = this._account.decryptedCredentials();

    if (!settings || !settings.imap_host) {
      return Promise.reject(new NylasError("ensureConnection: There are no IMAP connection settings for this account."))
    }
    if (!credentials) {
      return Promise.reject(new NylasError("ensureConnection: There are no IMAP connection credentials for this account."))
    }

    const conn = new IMAPConnection(this._db, Object.assign({}, settings, credentials));
    conn.on('mail', () => {
      this.onConnectionIdleUpdate();
    })
    conn.on('update', () => {
      this.onConnectionIdleUpdate();
    })
    conn.on('queue-empty', () => {
    });

    this._conn = conn;
    return this._conn.connect();
  }

  syncbackMessageActions() {
    const where = {where: {status: "NEW"}, limit: 100};
    return this._db.SyncbackRequest.findAll(where)
      .map((req) => SyncbackTaskFactory.create(this._account, req))
      .each(this.runSyncbackTask.bind(this))
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
    }).finally(() => syncbackRequest.save())
  }

  syncAllCategories() {
    const {Category} = this._db;
    const {folderSyncOptions} = this._account.syncPolicy;

    return Category.findAll({where: {type: 'folder'}}).then((categories) => {
      const priority = ['inbox', 'all', 'drafts', 'sent', 'spam', 'trash'].reverse();
      const categoriesToSync = categories.sort((a, b) =>
        (priority.indexOf(a.role) - priority.indexOf(b.role)) * -1
      )

      return Promise.all(categoriesToSync.map((cat) =>
        this._conn.runOperation(new FetchMessagesInCategory(cat, folderSyncOptions))
      ))
    });
  }

  performSync() {
    return this._conn.runOperation(new FetchCategoryList(this._account.provider))
    .then(() => this.syncbackMessageActions())
    .then(() => this.syncAllCategories())
  }

  syncNow() {
    clearTimeout(this._syncTimer);

    if (!process.env.SYNC_AFTER_ERRORS && this._account.errored()) {
      console.log(`SyncWorker: Account ${this._account.emailAddress} is in error state - Skipping sync`)
      return
    }

    this.ensureConnection()
    .then(() => this.performSync())
    .then(() => this.onSyncDidComplete())
    .catch((error) => this.onSyncError(error))
    .finally(() => {
      this._lastSyncTime = Date.now()
      this.scheduleNextSync()
    })
  }

  onSyncError(error) {
    console.error(`SyncWorker: Error while syncing account ${this._account.emailAddress} `, error)
    this.closeConnection()
    if (error.source === 'socket') {
      // Continue to retry if it was a network error
      return Promise.resolve()
    }
    this._account.syncError = error
    return this._account.save()
  }

  scheduleNextSync() {
    if (this._account.errored()) { return }
    SchedulerUtils.checkIfAccountIsActive(this._account.id).then((active) => {
      const {intervals} = this._account.syncPolicy;
      const interval = active ? intervals.active : intervals.inactive;

      if (interval) {
        const target = this._lastSyncTime + interval;
        console.log(`SyncWorker: Account ${active ? 'active' : 'inactive'}. Next sync scheduled for ${new Date(target).toLocaleString()}`);
        this._syncTimer = setTimeout(() => {
          this.syncNow();
        }, target - Date.now());
      }
    });
  }
}

module.exports = SyncWorker;
