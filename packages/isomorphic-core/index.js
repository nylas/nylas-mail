module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  Imap: require('imap'),
  IMAPConnection: require('./src/imap-connection'),
  IMAPErrors: require('./src/imap-errors'),
  PromiseUtils: require('./src/promise-utils'),
  loadModels: require('./src/models'),
}
