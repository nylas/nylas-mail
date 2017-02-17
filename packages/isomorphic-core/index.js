/* eslint global-require: 0 */
module.exports = {
  Provider: {
    Gmail: 'gmail',
    IMAP: 'imap',
  },
  Imap: require('imap'),
  Errors: require('./src/errors'),
  IMAPErrors: require('./src/imap-errors'),
  loadModels: require('./src/load-models'),
  AuthHelpers: require('./src/auth-helpers'),
  PromiseUtils: require('./src/promise-utils'),
  DatabaseTypes: require('./src/database-types'),
  IMAPConnection: require('./src/imap-connection'),
  SendmailClient: require('./src/sendmail-client'),
  DeltaStreamBuilder: require('./src/delta-stream-builder'),
  HookTransactionLog: require('./src/hook-transaction-log'),
  HookIncrementVersionOnSave: require('./src/hook-increment-version-on-save'),
  BackoffScheduler: require('./src/backoff-schedulers').BackoffScheduler,
  ExponentialBackoffScheduler: require('./src/backoff-schedulers').ExponentialBackoffScheduler,
  MetricsReporter: require('./src/metrics-reporter').default,
}
