NylasSyncWorkerPool = require('./nylas-sync-worker-pool').default

module.exports =
  activate: ->
    window.nylasSyncWorkerPool = new NylasSyncWorkerPool()

  deactivate: ->
