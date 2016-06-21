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
//   folderRecentSync: {
//     every: 60 * 1000,
//   },
//   folderDeepSync: {
//     every: 5 * 60 * 1000,
//   },
//   expiration: Date.now() + 60 * 60 * 1000,
// }

class SyncWorker {

  constructor(account, db) {
    this._db = db;
    this._conn = null;
    this._account = account;
    this._lastFolderRecentSync = null;
    this._lastFolderDeepSync = null;

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
    this.getInboxCategory((inboxCategory) => {
      this._conn.runOperation(new SyncMailboxOperation(inboxCategory, {
        scanAllUIDs: false,
        limit: this.account.syncPolicy.options,
      }));
    });
  }

  getInboxCategory() {
    return this._db.Category.find({where: {role: 'inbox'}})
  }

  getCurrentFolderSyncOptionsForPolicy() {
    const {folderRecentSync, folderDeepSync, limit} = this._account.syncPolicy;

    if (Date.now() - this._lastFolderDeepSync > folderDeepSync.every) {
      return {
        mode: 'deep',
        options: {
          scanAllUIDs: true,
          limit: limit,
        },
      };
    }
    if (Date.now() - this._lastFolderRecentSync > folderRecentSync.every) {
      return {
        mode: 'shallow',
        options: {
          scanAllUIDs: false,
          limit: limit,
        },
      };
    }
    return {
      mode: 'none',
    };
  }

  ensureConnection() {
    if (!this._conn) {
      const conn = new IMAPConnection(this._db, {
        user: 'inboxapptest1@fastmail.fm',
        password: 'trar2e',
        host: 'mail.messagingengine.com',
        port: 993,
        tls: true,
      });
      conn.on('mail', () => {
        this.onConnectionIdleUpdate();
      })
      conn.on('update', () => {
        this.onConnectionIdleUpdate();
      })
      conn.on('queue-empty', () => {
      });

      this._conn = conn;
    }

    return this._conn.connect();
  }

  queueOperationsForUpdates() {
    // todo: syncback operations belong here!
    return this._conn.runOperation(new RefreshMailboxesOperation())
  }

  queueOperationsForFolderSyncs() {
    const {Category} = this._db;
    const {mode, options} = this.getCurrentFolderSyncOptionsForPolicy();

    if (mode === 'none') {
      return Promise.resolve();
    }

    return Category.findAll().then((categories) => {
      const priority = ['inbox', 'drafts', 'sent'];
      const sorted = categories.sort((a, b) =>
        priority.indexOf(b.role) - priority.indexOf(a.role)
      )
      return Promise.all(sorted.map((cat) =>
        this._conn.runOperation(new SyncMailboxOperation(cat, options))
      )).then(() => {
        if (mode === 'deep') {
          this._lastFolderDeepSync = Date.now();
          this._lastFolderRecentSync = Date.now();
        } else if (mode === 'shallow') {
          this._lastFolderRecentSync = Date.now();
        }
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
    const {folderRecentSync, folderDeepSync} = this._account.syncPolicy;

    let target = Number.MAX_SAFE_INTEGER;

    if (folderRecentSync) {
      target = Math.min(target, this._lastFolderRecentSync + folderRecentSync.every);
    }
    if (folderDeepSync) {
      target = Math.min(target, this._lastFolderDeepSync + folderDeepSync.every);
    }

    console.log(`Next sync scheduled for ${new Date(target).toLocaleString()}`);

    this._syncTimer = setTimeout(() => {
      this.syncNow();
    }, target - Date.now());
  }
}

module.exports = SyncWorker;
