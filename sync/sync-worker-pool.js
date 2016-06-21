const SyncWorker = require('./sync-worker');
const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)

class SyncWorkerPool {
  constructor() {
    this._workers = {};
  }

  addWorkerForAccount(account) {
    account.syncPolicy = {
      limit: {
        after: Date.now() - 7 * 24 * 60 * 60 * 1000,
        count: 10000,
      },
      afterSync: 'idle',
      folderRecentSync: {
        every: 60 * 1000,
      },
      folderDeepSync: {
        every: 5 * 60 * 1000,
      },
      expiration: Date.now() + 60 * 60 * 1000,
    }

    DatabaseConnectionFactory.forAccount(account.id).then((db) => {
      this._workers[account.id] = new SyncWorker(account, db);
    });
  }
}

module.exports = SyncWorkerPool;
