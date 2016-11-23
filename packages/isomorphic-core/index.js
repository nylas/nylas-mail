module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  Imap: require('imap'),
  IMAPConnection: require('./imap-connection'),
  IMAPErrors: require('./imap-errors'),
  PromiseUtils: require('./promise-utils'),
}
