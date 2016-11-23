const _ = require('underscore')

function Logger(boundArgs = {}) {
  if (!_.isObject(boundArgs)) {
    throw new Error('Logger: Bound arguments must be an object')
  }
  const logger = {}
  const loggerFns = ['log', 'info', 'warn', 'error']
  loggerFns.forEach((logFn) => {
    logger[logFn] = (first, ...args) => {
      if (first instanceof Error || !_.isObject(first)) {
        if (_.isEmpty(boundArgs)) {
          return console[logFn](first, ...args)
        }
        return console[logFn](boundArgs, first, ...args)
      }
      return console[logFn]({...boundArgs, ...first}, ...args)
    }
  })
  logger.child = (extraBoundArgs) => Logger({...boundArgs, ...extraBoundArgs})
  return logger
}

function createLogger(name) {
  const childLogs = new Map()
  const logger = Logger({name})

  return Object.assign(logger, {
    forAccount(account = {}) {
      if (!childLogs.has(account.id)) {
        const childLog = logger.child({
          account_id: account.id,
          account_email: account.emailAddress,
        })
        childLogs.set(account.id, childLog)
      }
      return childLogs.get(account.id)
    },
  })
}

module.exports = {createLogger}
