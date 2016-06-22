const SyncWorker = require('./sync-worker');
const {DatabaseConnectionFactory} = require(`nylas-core`)

class SyncWorkerPool {
  constructor() {
    this._workers = {};
  }

  addWorkerForAccount(account) {
    DatabaseConnectionFactory.forAccount(account.id).then((db) => {
      this._workers[account.id] = new SyncWorker(account, db);
    });
  }
}

module.exports = SyncWorkerPool;
