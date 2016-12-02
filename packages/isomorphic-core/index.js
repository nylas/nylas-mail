/* eslint global-require: 0 */
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
  DeltaStreamBuilder: require('./src/delta-stream-builder'),
  HookTransactionLog: require('./src/hook-transaction-log'),
  HookIncrementVersionOnSave: require('./src/hook-increment-version-on-save'),
}
