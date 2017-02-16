AccountDeltaConnectionPool = require('./account-delta-connection-pool').default

module.exports =
  activate: ->
    window.nylasSyncWorkerPool = new AccountDeltaConnectionPool()

  deactivate: ->
