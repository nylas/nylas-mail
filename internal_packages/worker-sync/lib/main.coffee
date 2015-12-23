NylasSyncWorkerPool = require './nylas-sync-worker-pool'

module.exports =
  activate: ->
    pool = new NylasSyncWorkerPool()
    window.NylasSyncWorkerPool = pool

  deactivate: ->
