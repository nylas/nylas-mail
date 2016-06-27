global.Promise = require('bluebird');
global.NylasError = require('./nylas-error');

module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  DatabaseConnector: require('./database-connector'),
  PubsubConnector: require('./pubsub-connector'),
  IMAPConnection: require('./imap-connection'),
  SyncPolicy: require('./sync-policy'),
  SchedulerUtils: require('./scheduler-utils'),
  Config: require(`./config/${process.env.ENV || 'development'}`),
  NylasError,
}
