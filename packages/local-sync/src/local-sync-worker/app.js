const Metrics = require('../local-sync-metrics')
Metrics.startCapturing('nylas-k2-sync')

const {Logger} = require('nylas-core')
const LocalDatabaseConnector = require('../shared/local-database-connector')

global.Metrics = Metrics
global.Logger = Logger.createLogger('nylas-k2-sync')

const onUnhandledError = (err) => {
  global.Logger.fatal(err, 'Unhandled error')
  global.Metrics.reportError(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)


const prepareEnvironmentInfo = (callback) => {
  if (process.env.NODE_ENV === 'development') {
    const os = require('os')
    global.instanceId = os.hostname();
    callback();
  } else {
    const request = require('request')
    request('http://169.254.169.254/latest/meta-data/instance-id', (error, response, body) => {
      global.instanceId = body;
      callback();
    });
  }
}

prepareEnvironmentInfo(() => {
  const SyncProcessManager = require('./sync-process-manager')
  const manager = new SyncProcessManager();

  LocalDatabaseConnector.forShared().then((db) => {
    const {Account} = db;
    Account.findAll().then((accounts) => {
      if (accounts.length === 0) {
        global.Logger.info(`Couldn't find any accounts to sync. Run this CURL command to auth one!`)
        global.Logger.info(`curl -X POST -H "Content-Type: application/json" -d '{"email":"inboxapptest1@fastmail.fm", "name":"Ben Gotow", "provider":"imap", "settings":{"imap_username":"inboxapptest1@fastmail.fm","imap_host":"mail.messagingengine.com","imap_port":993,"smtp_host":"mail.messagingengine.com","smtp_port":0,"smtp_username":"inboxapptest1@fastmail.fm", "smtp_password":"trar2e","imap_password":"trar2e","ssl_required":true}}' "http://localhost:5100/auth?client_id=123"`)
      }
      manager.ensureAccountIDsInRedis(accounts.map(a => a.id)).then(() => {
        manager.start();
      })
    });
  });

  global.manager = manager;
});
