global.Promise = require('bluebird');

const {DatabaseConnectionFactory} = require(`nylas-core`)
const SyncWorkerPool = require('./sync-worker-pool');
const workerPool = new SyncWorkerPool();

const start = () => {
  DatabaseConnectionFactory.forShared().then((db) => {
    const {Account} = db;
    Account.findAll().then((accounts) => {
      if (accounts.length === 0) {
        console.log(`Couldn't find any accounts to sync. Run this CURL command to auth one!`)
        console.log(`curl -X POST -H "Content-Type: application/json" -d '{"email":"inboxapptest2@fastmail.fm", "name":"Ben Gotow", "provider":"imap", "settings":{"imap_username":"inboxapptest1@fastmail.fm","imap_host":"mail.amessagingengine.com","imap_port":993,"smtp_host":"mail.messagingengine.com","smtp_port":0,"smtp_username":"inboxapptest1@fastmail.fm", "smtp_password":"trar2e","imap_password":"trar2e","ssl_required":true}}' "http://localhost:5100/auth?client_id=123"`)
      }
      accounts.forEach((account) => {
        workerPool.addWorkerForAccount(account);
      });
    });
  });
}

start();

global.workerPool = workerPool;
