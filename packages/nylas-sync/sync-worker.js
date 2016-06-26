const {
  SchedulerUtils,
  IMAPConnection,
  PubsubConnector,
  DatabaseConnector,
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

    this._listener = PubsubConnector.observableForAccountChanges(account.id)
    .subscribe(() => this.onAccountChanged())
  }

  cleanup() {
    this._destroyed = true;
    this._listener.dispose();
    this._conn.end();
  }

  onAccountChanged() {
    console.log("SyncWorker: Detected change to account. Reloading and syncing now.")
    DatabaseConnector.forShared().then(({Account}) => {
      Account.find({where: {id: this._account.id}}).then((account) => {
        this._account = account;
        this.syncNow();
      })
    });
  }

  onSyncDidComplete() {
    const {afterSync} = this._account.syncPolicy;

    if (afterSync === 'idle') {
      return this.getInboxCategory()
      .then((inboxCategory) => {
        this._conn.openBox(inboxCategory.name).then(() => {
          console.log("SyncWorker: - Idling on inbox category");
        })
      });
    } else if (afterSync === 'close') {
      console.log("SyncWorker: - Closing connection");
      this._conn.end();
      this._conn = null;
      return Promise.resolve()
    }
    return Promise.reject(new Error(`onSyncDidComplete: Unknown afterSync behavior: ${afterSync}`))
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
    return new Promise((resolve, reject) => {
      const settings = this._account.connectionSettings;
      const credentials = this._account.decryptedCredentials();

      if (!settings || !settings.imap_host) {
        return reject(new Error("ensureConnection: There are no IMAP connection settings for this account."))
      }
      if (!credentials) {
        return reject(new Error("ensureConnection: There are no IMAP connection credentials for this account."))
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
      resolve(this._conn.connect());
    });
  }

  fetchCategoryList() {
    return this._conn.runOperation(new FetchCategoryList())
  }

  syncbackMessageActions() {
    return Promise.resolve();
    // TODO
    const {SyncbackRequest, accountId, Account} = this._db;

    return Account.find({where: {id: accountId}}).then((account) => {
      return Promise.each(SyncbackRequest.findAll().then((reqs = []) =>
        reqs.map((request) => {
          const task = SyncbackTaskFactory.create(account, request);
          return this._conn.runOperation(task)
        })
      ));
    });
  }

  fetchMessagesInCategory() {
    const {Category} = this._db;
    const {folderSyncOptions} = this._account.syncPolicy;

    return Category.findAll().then((categories) => {
      const priority = ['inbox', 'drafts', 'sent'].reverse();
      const categoriesToSync = categories.sort((a, b) =>
        (priority.indexOf(a.role) - priority.indexOf(b.role)) * -1
      )

      // const filtered = sorted.filter(cat =>
      //   ['[Gmail]/All Mail', '[Gmail]/Trash', '[Gmail]/Spam'].includes(cat.name)
      // )

      return Promise.all(categoriesToSync.map((cat) =>
        this._conn.runOperation(new FetchMessagesInCategory(cat, folderSyncOptions))
      ))
    });
  }

  syncNow() {
    clearTimeout(this._syncTimer);

    this.ensureConnection()
    .then(this.fetchCategoryList.bind(this))
    .then(this.syncbackMessageActions.bind(this))
    .then(this.fetchMessagesInCategory.bind(this))
    // TODO Update account sync state in this error handler
    .catch(console.error)
    .finally(() => {
      this._lastSyncTime = Date.now()
      this.onSyncDidComplete()
      .catch((error) => console.error('SyncWorker.syncNow: Unhandled error while cleaning up sync: ', error))
      .finally(() => this.scheduleNextSync())
    });
  }

  scheduleNextSync() {
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
