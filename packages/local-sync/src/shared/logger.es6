const _ = require('underscore')

let ENABLE_LOGGING = true;
const LOGGER_COLORS = [
  '#E91E63',
  '#9C27B0',
  '#673AB7',
  '#3F51B5',
  '#2196F3',
  '#009688',
  '#4CAF50',
  '#FF5722',
  '#795548',
  '#607D8B',
]
const colorsByPrefix = {}
let curColor = 0

function getColorForPrefix(prefix) {
  if (colorsByPrefix[prefix]) {
    return colorsByPrefix[prefix]
  }
  colorsByPrefix[prefix] = LOGGER_COLORS[curColor]
  curColor = (curColor + 1) % LOGGER_COLORS.length
  return colorsByPrefix[prefix]
}

function Logger(boundArgs = {}) {
  if (NylasEnv && !NylasEnv.inDevMode()) {
    ENABLE_LOGGING = false
  }

  if (!_.isObject(boundArgs)) {
    throw new Error('Logger: Bound arguments must be an object')
  }
  const logger = {}
  const loggerFns = ['log', 'debug', 'info', 'warn', 'error']
  loggerFns.forEach((logFn) => {
    logger[logFn] = (...args) => {
      if (!ENABLE_LOGGING && logFn !== "error") {
        return () => {}
      }
      const {accountId, accountEmail, ...otherArgs} = boundArgs
      const prefix = accountEmail || accountId
      const suffix = !_.isEmpty(otherArgs) ? otherArgs : '';
      if (prefix) {
        const color = getColorForPrefix(prefix)
        return console[logFn](
          `%c<${prefix}>`,
          `color: ${color}`,
          ...args,
          suffix
        )
      }
      return console[logFn](...args, suffix)
    }
  })
  logger.child = (extraBoundArgs) => Logger({...boundArgs, ...extraBoundArgs})
  return logger
}

function createLogger() {
  const childLogs = new Map()
  const logger = Logger()

  return Object.assign(logger, {
    forAccount(account = {}) {
      if (!childLogs.has(account.id)) {
        const childLog = logger.child({
          accountId: account.id,
          accountEmail: account.emailAddress,
        })
        childLogs.set(account.id, childLog)
      }
      return childLogs.get(account.id)
    },
  })
}

module.exports = {createLogger}
