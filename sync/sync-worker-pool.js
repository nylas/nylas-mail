const SyncWorker = require('./sync-worker');
const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)

class SyncWorkerPool {
  constructor() {
    this._workers = {};
  }

  addWorkerForAccount(account) {
    account.syncPolicy = {
      afterSync: 'idle',
      interval: 30 * 1000,
      folderSyncOptions: {
        deepFolderScan: 5 * 60 * 1000,
      },
      expiration: Date.now() + 60 * 60 * 1000,
    }

    DatabaseConnectionFactory.forAccount(account.id).then((db) => {
      this._workers[account.id] = new SyncWorker(account, db);
    });
  }
}

module.exports = SyncWorkerPool;
