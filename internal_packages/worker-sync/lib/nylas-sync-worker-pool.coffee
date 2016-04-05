_ = require 'underscore'

{NylasAPI,
 Actions,
 AccountStore,
 DatabaseStore,
 MailRulesProcessor,
 DatabaseObjectRegistry} = require 'nylas-exports'

NylasLongConnection = require './nylas-long-connection'
NylasSyncWorker = require './nylas-sync-worker'

class NylasSyncWorkerPool

  constructor: ->
    @_workers = []

    AccountStore.listen(@_onAccountsChanged, @)
    @_onAccountsChanged()

  _onAccountsChanged: ->
    return if NylasEnv.inSpecMode()

    accounts = AccountStore.accounts()
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

    # Remove any metadata deltas. These have to be handled at the end, since metadata
    # is stored within the object that it points to (which may not exist yet)
    metadata = []
    for deltas in [create, modify]
      if deltas['metadata']
        metadata = metadata.concat(_.values(deltas['metadata']))
        delete deltas['metadata']

    # Remove any account deltas, which are only used to notify broken/fixed sync state
    # on accounts
    delete create['account']
    delete destroy['account']
    if modify['account']
      @_handleAccountDeltas(_.values(modify['account']))
      delete modify['account']

    # Apply all the deltas to create objects. Gets promises for handling
    # each type of model in the `create` hash, waits for them all to resolve.
    create[type] = NylasAPI._handleModelResponse(_.values(dict)) for type, dict of create
    Promise.props(create).then (created) =>
      # Apply all the deltas to modify objects. Gets promises for handling
      # each type of model in the `modify` hash, waits for them all to resolve.
      modify[type] = NylasAPI._handleModelResponse(_.values(dict)) for type, dict of modify
      Promise.props(modify).then (modified) =>

        Promise.all(@_handleDeltaMetadata(metadata)).then =>

          # Now that we've persisted creates/updates, fire an action
          # that allows other parts of the app to update based on new models
          # (notifications)
          if _.flatten(_.values(created)).length > 0
            MailRulesProcessor.processMessages(created['message'] ? []).finally =>
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

  _handleDeltaMetadata: (metadata) =>
    metadata.map (metadatum) =>
      klass = NylasAPI._apiObjectToClassMap[metadatum.object_type]
      DatabaseStore.inTransaction (t) =>
        t.find(klass, metadatum.object_id).then (model) ->
          return Promise.resolve() unless model
          model = model.applyPluginMetadata(metadatum.application_id, metadatum.value)
          localMetadatum = model.metadataObjectForPluginId(metadatum.application_id)
          localMetadatum.version = metadatum.version
          t.persistModel(model)

  _handleAccountDeltas: (deltas) =>
    for delta in deltas
      Actions.updateAccount(delta.account_id, {syncState: delta.sync_state})
      Actions.recordUserEvent('Account State Delta', {
        accountId: delta.account_id
        accountEmail: delta.email_address
        syncState: delta.sync_state
      })

  _handleDeltaDeletion: (delta) =>
    klass = NylasAPI._apiObjectToClassMap[delta.object]
    return unless klass

    DatabaseStore.inTransaction (t) =>
      t.find(klass, delta.id).then (model) ->
        return Promise.resolve() unless model
        return t.unpersistModel(model)

module.exports = NylasSyncWorkerPool
