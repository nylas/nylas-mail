module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  Imap: require('imap'),
  IMAPConnection: require('./src/imap-connection'),
  IMAPErrors: require('./src/imap-errors'),
  PromiseUtils: require('./src/promise-utils'),
  DatabaseTypes: require('./src/database-types'),
  loadModels: require('./src/load-models'),
  deltaStreamBuilder: require('./src/delta-stream-builder'),
}
