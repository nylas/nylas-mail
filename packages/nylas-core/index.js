global.Promise = require('bluebird');

module.exports = {
  DatabaseConnector: require('./database-connector'),
  PubsubConnector: require('./pubsub-connector'),
  IMAPConnection: require('./imap-connection'),
  SyncPolicy: require('./sync-policy'),
  SchedulerUtils: require('./scheduler-utils'),
  Config: require(`./config/${process.env.ENV || 'development'}`),
  ExtendableError: require('./extendable-error'),
}
