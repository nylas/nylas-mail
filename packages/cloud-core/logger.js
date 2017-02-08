const bunyan = require('bunyan')
const {getLogStreams} = require('./log-streams')
const NODE_ENV = process.env.NODE_ENV || 'unknown'

function createLogger(name, env = NODE_ENV) {
  const logger = bunyan.createLogger({
    name,
    env,
    serializers: bunyan.stdSerializers,
    streams: getLogStreams(name, env),
  })

  return Object.assign(logger, {
    forAccount(account = {}, parentLogger = logger) {
      return parentLogger.child({
        account_id: account.id,
        account_email: account.emailAddress,
        account_provider: account.provider,
        n1_id: account.n1IdentityToken || 'Not available',
      });
    },
  });
}

module.exports = {
  createLogger,
}
