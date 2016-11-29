NylasSyncWorkerPool = require('./nylas-sync-worker-pool').default

module.exports =
  activate: ->
    new NylasSyncWorkerPool()

  deactivate: ->
