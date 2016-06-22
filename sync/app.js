const path = require('path');

global.__base = path.join(__dirname, '..')
global.config = require(`${__base}/core/config/${process.env.ENV || 'development'}.json`);
global.Promise = require('bluebird');

const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)
const SyncWorkerPool = require('./sync-worker-pool');
const workerPool = new SyncWorkerPool();

const seed = (db) => {
  const {Account, AccountToken} = db;

  const account = Account.build({
    emailAddress: 'inboxapptest1@fastmail.fm',
    connectionSettings: {
      imap: {
        host: 'mail.messagingengine.com',
        port: 993,
        tls: true,
      },
    },
    syncPolicy: {
      afterSync: 'idle',
      interval: 30 * 1000,
      folderSyncOptions: {
        deepFolderScan: 5 * 60 * 1000,
      },
      expiration: Date.now() + 60 * 60 * 1000,
    },
  })
  account.setCredentials({
    imap: {
      user: 'inboxapptest1@fastmail.fm',
      password: 'trar2e',
    },
    smtp: {
      user: 'inboxapptest1@fastmail.fm',
      password: 'trar2e',
    },
  });
  return account.save().then((obj) =>
    AccountToken.create({
      AccountId: obj.id,
    }).then((token) => {
      console.log(`Created seed data. Your API token is ${token.value}`)
    })
  );
}

const start = () => {
  DatabaseConnectionFactory.forShared().then((db) => {
    const {Account} = db;
    Account.findAll().then((accounts) => {
      if (accounts.length === 0) {
        seed(db).then(start);
      }
      accounts.forEach((account) => {
        workerPool.addWorkerForAccount(account);
      });
    });
  });
}

DatabaseConnectionFactory.setup()
start();

global.workerPool = workerPool;
