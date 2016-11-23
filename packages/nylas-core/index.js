module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  Imap: require('imap'),
  IMAPConnection: require('./imap-connection'),
  MessageTypes: require('./message-types'),
  Logger: require('./logger'),
  Errors: require('./imap-errors'),
  PromiseUtils: require('./promise-utils'),
}
