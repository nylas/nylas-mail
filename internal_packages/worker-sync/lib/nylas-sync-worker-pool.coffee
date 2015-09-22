_ = require 'underscore'

{NylasAPI,
 Actions,
 AccountStore,
 DatabaseStore,
 DatabaseObjectRegistry} = require 'nylas-exports'

NylasLongConnection = require './nylas-long-connection'
NylasSyncWorker = require './nylas-sync-worker'


class NylasSyncWorkerPool

  constructor: ->
    @_workers = []
    AccountStore.listen(@_onAccountsChanged, @)
    @_onAccountsChanged()

  _onAccountsChanged: ->
    return if atom.inSpecMode()

    accounts = AccountStore.items()
    workers = _.map(accounts, @workerForAccount)

    # Stop the workers that are not in the new workers list.
    # These accounts are no longer in our database, so we shouldn't
    # be listening.
    old = _.without(@_workers, workers...)
    worker.cleanup() for worker in old

    @_workers = workers

  workers: =>
    @_workers

  workerForAccount: (account) =>
    worker = _.find @_workers, (c) -> c.account().id is account.id
    return worker if worker

    worker = new NylasSyncWorker(NylasAPI, account)
    connection = worker.connection()

    connection.onStateChange (state) ->
      Actions.longPollStateChanged({accountId: account.id, state: state})
      if state == NylasLongConnection.State.Connected
        ## TODO use OfflineStatusStore
        Actions.longPollConnected()
      else
        ## TODO use OfflineStatusStore
        Actions.longPollOffline()

    connection.onDeltas (deltas) =>
      @_handleDeltas(deltas)

    @_workers.push(worker)
    worker.start()
    worker

  _cleanupAccountWorkers: ->
    for worker in @_workers
      worker.cleanup()
    @_workers = []

  _handleDeltas: (deltas) ->
    Actions.longPollReceivedRawDeltas(deltas)
    Actions.longPollReceivedRawDeltasPing(deltas.length)

    # Create a (non-enumerable) reference from the attributes which we carry forward
    # back to their original deltas. This allows us to mark the deltas that the
    # app ignores later in the process.
    deltas.forEach (delta) ->
      if delta.attributes
        Object.defineProperty(delta.attributes, '_delta', { get: -> delta })

    {create, modify, destroy} = @_clusterDeltas(deltas)

    # Apply all the deltas to create objects. Gets promises for handling
    # each type of model in the `create` hash, waits for them all to resolve.
    create[type] = NylasAPI._handleModelResponse(_.values(dict)) for type, dict of create
    Promise.props(create).then (created) =>
      # Apply all the deltas to modify objects. Gets promises for handling
      # each type of model in the `modify` hash, waits for them all to resolve.
      modify[type] = NylasAPI._handleModelResponse(_.values(dict)) for type, dict of modify
      Promise.props(modify).then (modified) =>

        # Now that we've persisted creates/updates, fire an action
        # that allows other parts of the app to update based on new models
        # (notifications)
        if _.flatten(_.values(created)).length > 0
          Actions.didPassivelyReceiveNewModels(created)

        # Apply all of the deletions
        destroyPromises = destroy.map(@_handleDeltaDeletion)
        Promise.settle(destroyPromises).then =>
          Actions.longPollProcessedDeltas()

  _clusterDeltas: (deltas) ->
    # Group deltas by object type so we can mutate the cache efficiently.
    # NOTE: This code must not just accumulate creates, modifies and destroys
    # but also de-dupe them. We cannot call "persistModels(itemA, itemA, itemB)"
    # or it will throw an exception - use the last received copy of each model
    # we see.
    create = {}
    modify = {}
    destroy = []
    for delta in deltas
      if delta.event is 'create'
        create[delta.object] ||= {}
        create[delta.object][delta.attributes.id] = delta.attributes
      else if delta.event is 'modify'
        modify[delta.object] ||= {}
        modify[delta.object][delta.attributes.id] = delta.attributes
      else if delta.event is 'delete'
        destroy.push(delta)

    {create, modify, destroy}

  _handleDeltaDeletion: (delta) =>
    klass = NylasAPI._apiObjectToClassMap[delta.object]
    return unless klass
    DatabaseStore.find(klass, delta.id).then (model) ->
      return Promise.resolve() unless model
      return DatabaseStore.unpersistModel(model)

pool = new NylasSyncWorkerPool()
window.NylasSyncWorkerPool = pool
module.exports = pool
