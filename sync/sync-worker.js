const IMAPConnection = require('./imap/connection');
const RefreshMailboxesOperation = require('./imap/refresh-mailboxes-operation')
const SyncMailboxOperation = require('./imap/sync-mailbox-operation')
//
// account.syncPolicy = {
//   afterSync: 'idle',
//   limit: {
//     after: Date.now() - 7 * 24 * 60 * 60 * 1000,
//     count: 10000,
//   },
//   interval: 60 * 1000,
//   folderSyncOptions: {
//     deepFolderScan: 5 * 60 * 1000,
//   },
//   expiration: Date.now() + 60 * 60 * 1000,
// }

class SyncWorker {

  constructor(account, db) {
    this._db = db;
    this._conn = null;
    this._account = account;
    this._lastSyncTime = null;

    this._syncTimer = null;
    this._expirationTimer = null;

    this.syncNow();
    this.scheduleExpiration();
  }

  // TODO: How does this get called?
  onAccountChanged() {
    this.syncNow();
    this.scheduleExpiration();
  }

  onExpired() {
    // Returning syncs to the unclaimed queue every so often is healthy.
    // TODO: That.
  }

  onSyncDidComplete() {
    const {afterSync} = this._account.syncPolicy;

    if (afterSync === 'idle') {
      this.getInboxCategory().then((inboxCategory) => {
        this._conn.openBox(inboxCategory.name, true).then(() => {
          console.log(" - Idling on inbox category");
        });
      });
    } else if (afterSync === 'close') {
      console.log(" - Closing connection");
      this._conn.end();
      this._conn = null;
    } else {
      throw new Error(`onSyncDidComplete: Unknown afterSync behavior: ${afterSync}`)
    }
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
    return new Promise((resolve) => {
      const settings = this._account.connectionSettings;
      const credentials = this._account.decryptedCredentials();

      if (!settings || !settings.imap) {
        throw new Error("ensureConnection: There are no IMAP connection settings for this account.")
      }
      if (!credentials || !credentials.imap) {
        throw new Error("ensureConnection: There are no IMAP connection credentials for this account.")
      }

      const conn = new IMAPConnection(this._db, Object.assign({}, settings.imap, credentials.imap));
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

  queueOperationsForUpdates() {
    // todo: syncback operations belong here!
    return this._conn.runOperation(new RefreshMailboxesOperation())
  }

  queueOperationsForFolderSyncs() {
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
        this._conn.runOperation(new SyncMailboxOperation(cat, folderSyncOptions))
      )).then(() => {
        this._lastSyncTime = Date.now();
      });
    });
  }

  syncNow() {
    clearTimeout(this._syncTimer);

    this.ensureConnection().then(() =>
      this.queueOperationsForUpdates().then(() =>
        this.queueOperationsForFolderSyncs()
      )
    ).catch((err) => {
      // Sync has failed for some reason. What do we do?!
      console.error(err);
    }).finally(() => {
      this.onSyncDidComplete();
      this.scheduleNextSync();
    });
  }

  scheduleExpiration() {
    const {expiration} = this._account.syncPolicy;

    clearTimeout(this._expirationTimer);
    this._expirationTimer = setTimeout(() => this.onExpired(), expiration);
  }

  scheduleNextSync() {
    const {interval} = this._account.syncPolicy;

    if (interval) {
      const target = this._lastSyncTime + interval;
      console.log(`Next sync scheduled for ${new Date(target).toLocaleString()}`);
      this._syncTimer = setTimeout(() => {
        this.syncNow();
      }, target - Date.now());
    }
  }
}

module.exports = SyncWorker;
