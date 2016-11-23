const LocalDatabaseConnector = require('../shared/local-database-connector')
const os = require('os')
global.instanceId = os.hostname();

const manager = require('./sync-process-manager')

LocalDatabaseConnector.forShared().then((db) => {
  const {Account} = db;
  Account.findAll().then((accounts) => {
    if (accounts.length === 0) {
      global.Logger.info(`Couldn't find any accounts to sync. Run this CURL command to auth one!`)
      global.Logger.info(`curl -X POST -H "Content-Type: application/json" -d '{"email":"inboxapptest1@fastmail.fm", "name":"Ben Gotow", "provider":"imap", "settings":{"imap_username":"inboxapptest1@fastmail.fm","imap_host":"mail.messagingengine.com","imap_port":993,"smtp_host":"mail.messagingengine.com","smtp_port":0,"smtp_username":"inboxapptest1@fastmail.fm", "smtp_password":"trar2e","imap_password":"trar2e","ssl_required":true}}' "http://localhost:2578/auth?client_id=123"`)
    }
    manager.start();
  });
});

global.manager = manager;
