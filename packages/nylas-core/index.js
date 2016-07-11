global.Promise = require('bluebird');

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
  MessageTypes: require('./message-types'),
  Logger: require('./logger'),
}
