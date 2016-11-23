module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  DatabaseConnector: require('./database-connector'),
  Imap: require('imap'),
  IMAPConnection: require('./imap-connection'),
  SyncPolicy: require('./sync-policy'),
  MessageTypes: require('./message-types'),
  Logger: require('./logger'),
  Errors: require('./imap-errors'),
  PromiseUtils: require('./promise-utils'),
}
