const path = require('path');

global.__base = path.join(__dirname, '..')
global.config = require(`${__base}/core/config/${process.env.ENV || 'development'}.json`);
global.Promise = require('bluebird');

const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)
const SyncWorkerPool = require('./sync-worker-pool');
const workerPool = new SyncWorkerPool();

const RedisServer = require('redis-server');
const redisServerInstance = new RedisServer(6379);

const start = () => {
  DatabaseConnectionFactory.setup()
  DatabaseConnectionFactory.forShared().then((db) => {
    const {Account} = db
    Account.findAll().then((accounts) => {
      accounts.forEach((account) => {
        workerPool.addWorkerForAccount(account);
      });
    });
  });
}

redisServerInstance.open((error) => {
  if (error) {
    console.error(error)
    process.exit(1);
  }
  start()
});

global.workerPool = workerPool;
