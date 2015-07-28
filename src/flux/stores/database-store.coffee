_ = require 'underscore'
path = require 'path'

Model = require '../models/model'
Actions = require '../actions'
LocalLink = require '../models/local-link'
ModelQuery = require '../models/query'
NylasStore = require '../../../exports/nylas-store'
DatabaseConnection = require './database-connection'

{AttributeCollection, AttributeJoinedData} = require '../attributes'

{tableNameForJoin,
 generateTempId,
 isTempId} = require '../models/utils'

DatabaseVersion = 5

###
Public: Nylas Mail is built on top of a custom database layer modeled after
ActiveRecord. For many parts of the application, the database is the source
of truth. Data is retrieved from the API, written to the database, and changes
to the database trigger Stores and components to refresh their contents.

The DatabaseStore is available in every application window and allows you to
make queries against the local cache. Every change to the local cache is
broadcast as a change event, and listening to the DatabaseStore keeps the
rest of the application in sync.

## Listening for Changes

To listen for changes to the local cache, subscribe to the DatabaseStore and
inspect the changes that are sent to your listener method.

```coffeescript
@unsubscribe = DatabaseStore.listen(@_onDataChanged, @)

...

_onDataChanged: (change) ->
  return unless change.objectClass is Message
  return unless @_myMessageID in _.map change.objects, (m) -> m.id

  # Refresh Data

```

The local cache changes very frequently, and your stores and components should
carefully choose when to refresh their data. The `change` object passed to your
event handler allows you to decide whether to refresh your data and exposes
the following keys:

`objectClass`: The {Model} class that has been changed. If multiple types of models
were saved to the database, you will receive multiple change events.

`objects`: An {Array} of {Model} instances that were either created, updated or
deleted from the local cache. If your component or store presents a single object
or a small collection of objects, you should look to see if any of the objects
are in your displayed set before refreshing.

Section: Database
###
class DatabaseStore extends NylasStore

  constructor: ->
    @_triggerPromise = null
    @_localIdLookupCache = {}

    if atom.inSpecMode()
      @_databasePath = path.join(atom.getConfigDirPath(),'edgehill.test.db')
    else
      @_databasePath = path.join(atom.getConfigDirPath(),'edgehill.db')

    @_dbConnection = new DatabaseConnection(@_databasePath, DatabaseVersion)

    # It's important that this defer is here because we can't let queries
    # commence while the app is in its `require` phase. We'll queue all of
    # the reqeusts before the DB is setup and handle them properly later
    _.defer =>
      @_dbConnection.connect() unless atom.inSpecMode()

  # Returns a promise that resolves when the query has been completed and
  # rejects when the query has failed.
  #
  # If a query is made while the connection is being setup, the
  # DatabaseConnection will queue the queries and fire them after it has
  # been setup. The Promise returned here wont resolve until that happens
  _query: (query, values=[], options={}) =>
    return @_dbConnection.query(query, values, options)

  ########################################################################
  ########################### PUBLIC METHODS #############################
  ########################################################################

  ###
  ActiveRecord-style Querying
  ###

  # Public: Creates a new Model Query for retrieving a single model specified by
  # the class and id.
  #
  # - `class` The class of the {Model} you're trying to retrieve.
  # - `id` The {String} id of the {Model} you're trying to retrieve
  #
  # Example:
  # ```coffee
  # DatabaseStore.find(Thread, 'id-123').then (thread) ->
  #   # thread is a Thread object, or null if no match was found.
  # ```
  #
  # Returns a {ModelQuery}
  #
  find: (klass, id) =>
    throw new Error("You must provide a class to findByLocalId") unless klass
    throw new Error("find takes a string id. You may have intended to use findBy.") unless _.isString(id)
    new ModelQuery(klass, @).where({id:id}).one()

  # Public: Creates a new Model Query for retrieving a single model matching the
  # predicates provided.
  #
  # - `class` The class of the {Model} you're trying to retrieve.
  # - `predicates` An {Array} of {matcher} objects. The set of predicates the
  #    returned model must match.
  #
  # Returns a {ModelQuery}
  #
  findBy: (klass, predicates = []) =>
    throw new Error("You must provide a class to findBy") unless klass
    new ModelQuery(klass, @).where(predicates).one()

  # Public: Creates a new Model Query for retrieving all models matching the
  # predicates provided.
  #
  # - `class` The class of the {Model} you're trying to retrieve.
  # - `predicates` An {Array} of {matcher} objects. The set of predicates the
  #    returned model must match.
  #
  # Returns a {ModelQuery}
  #
  findAll: (klass, predicates = []) =>
    throw new Error("You must provide a class to findAll") unless klass
    new ModelQuery(klass, @).where(predicates)

  # Public: Creates a new Model Query that returns the {Number} of models matching
  # the predicates provided.
  #
  # - `class` The class of the {Model} you're trying to retrieve.
  # - `predicates` An {Array} of {matcher} objects. The set of predicates the
  #    returned model must match.
  #
  # Returns a {ModelQuery}
  #
  count: (klass, predicates = []) =>
    throw new Error("You must provide a class to count") unless klass
    new ModelQuery(klass, @).where(predicates).count()

  ###
  Support for Local IDs
  ###

  # Public: Retrieve a Model given a localId.
  #
  # - `class` The class of the {Model} you're trying to retrieve.
  # - `localId` The {String} localId of the object.
  #
  # Returns a {Promise} that:
  #   - resolves with the Model associated with the localId
  #   - rejects if no matching object is found
  #
  # Note: When fetching an object by local Id, joined attributes
  # (like body, stored in a separate table) are always included.
  #
  findByLocalId: (klass, localId) =>
    return Promise.reject(new Error("You must provide a class to findByLocalId")) unless klass
    return Promise.reject(new Error("You must provide a local Id to findByLocalId")) unless localId

    new Promise (resolve, reject) =>
      @find(LocalLink, localId).then (link) =>
        return reject("Find by local ID lookup failed") unless link
        query = @find(klass, link.objectId).includeAll().then(resolve)

  # Public: Give a Model a localId.
  #
  # - `model` A {Model} object to assign a localId.
  # - `localId` (optional) The {String} localId. If you don't pass a LocalId, one
  #    will be automatically assigned.
  #
  # Returns a {Promise} that:
  #   - resolves with the localId assigned to the model
  bindToLocalId: (model, localId = null) =>
    return Promise.reject(new Error("You must provide a model to bindToLocalId")) unless model

    new Promise (resolve, reject) =>
      unless localId
        if isTempId(model.id)
          localId = model.id
        else
          localId = generateTempId()

      link = new LocalLink({id: localId, objectId: model.id})
      @_localIdLookupCache[model.id] = localId

      @persistModel(link).then ->
        resolve(localId)
      .catch(reject)

  # Public: Look up the localId assigned to the model. If no localId has been
  # assigned to the model yet, it assigns a new one and persists it to the database.
  #
  # - `model` A {Model} object to assign a localId.
  #
  # Returns a {Promise} that:
  #   - resolves with the {String} localId.
  localIdForModel: (model) =>
    return Promise.reject(new Error("You must provide a model to localIdForModel")) unless model

    new Promise (resolve, reject) =>
      if @_localIdLookupCache[model.id]
        return resolve(@_localIdLookupCache[model.id])

      @findBy(LocalLink, {objectId: model.id}).then (link) =>
        if link
          @_localIdLookupCache[model.id] = link.id
          resolve(link.id)
        else
          @bindToLocalId(model).then(resolve).catch(reject)

  # Public: Executes a {ModelQuery} on the local database.
  #
  # - `modelQuery` A {ModelQuery} to execute.
  #
  # Returns a {Promise} that
  #   - resolves with the result of the database query.
  run: (modelQuery) =>
    @_query(modelQuery.sql(), [], null, null, modelQuery.executeOptions())
    .then (result) ->
      Promise.resolve(modelQuery.formatResult(result))

  # Public: Asynchronously writes `model` to the cache and triggers a change event.
  #
  # - `model` A {Model} to write to the database.
  #
  # Returns a {Promise} that
  #   - resolves after the database queries are complete and any listening
  #     database callbacks have finished
  #   - rejects if any databse query fails or one of the triggering
  #     callbacks failed
  persistModel: (model) =>
    return Promise.all([
      Promise.all([
        @_query('BEGIN TRANSACTION')
        @_writeModels([model])
        @_query('COMMIT')
      ]),
      @_triggerSoon({objectClass: model.constructor.name, objects: [model], type: 'persist'})
    ])

  # Public: Asynchronously writes `models` to the cache and triggers a single change
  # event. Note: Models must be of the same class to be persisted in a batch operation.
  #
  # - `models` An {Array} of {Model} objects to write to the database.
  #
  # Returns a {Promise} that
  #   - resolves after the database queries are complete and any listening
  #     database callbacks have finished
  #   - rejects if any databse query fails or one of the triggering
  #     callbacks failed
  persistModels: (models=[]) =>
    return Promise.resolve() if models.length is 0
    klass = models[0].constructor
    ids = {}
    for model in models
      unless model.constructor == klass
        throw new Error("persistModels(): When you batch persist objects, they must be of the same type")
      if ids[model.id]
        throw new Error("persistModels(): You must pass an array of models with different ids. ID #{model.id} is in the set multiple times.")
      ids[model.id] = true

    return Promise.all([
      Promise.all([
        @_query('BEGIN TRANSACTION')
        @_writeModels(models)
        @_query('COMMIT')
      ]),
      @_triggerSoon({objectClass: models[0].constructor.name, objects: models, type: 'persist'})
    ])

  # Public: Asynchronously removes `model` from the cache and triggers a change event.
  #
  # - `model` A {Model} to write to the database.
  #
  # Returns a {Promise} that
  #   - resolves after the database queries are complete and any listening
  #     database callbacks have finished
  #   - rejects if any databse query fails or one of the triggering
  #     callbacks failed
  unpersistModel: (model) =>
    return Promise.all([
      Promise.all([
        @_query('BEGIN TRANSACTION')
        @_deleteModel(model)
        @_query('COMMIT')
      ]),
      @_triggerSoon({objectClass: model.constructor.name, objects: [model], type: 'unpersist'})
    ])

  # Public: Given an `oldModel` with a unique `localId`, it will swap the
  # item out in the database.
  #
  # - `args` An arguments hash with:
  #   - `oldModel` The old model
  #   - `newModel` The new model
  #   - `localId` The localId to reference
  #
  # Returns a {Promise} that
  #   - resolves after the database queries are complete and any listening
  #     database callbacks have finished
  #   - rejects if any databse query fails or one of the triggering
  #     callbacks failed
  swapModel: ({oldModel, newModel, localId}) =>
    queryPromise = Promise.all([
      @_query('BEGIN TRANSACTION')
      @_deleteModel(oldModel)
      @_writeModels([newModel])
      @_writeModels([new LocalLink(id: localId, objectId: newModel.id)]) if localId
      @_query('COMMIT')
    ])

    swapPromise = new Promise (resolve, reject) ->
      Actions.didSwapModel({
        oldModel: oldModel,
        newModel: newModel,
        localId: localId
      })
      resolve()

    triggerPromise = @_triggerSoon({objectClass: newModel.constructor.name, objects: [oldModel, newModel], type: 'swap'})

    return Promise.all([queryPromise, swapPromise, triggerPromise])


  ########################################################################
  ########################### PRIVATE METHODS ############################
  ########################################################################

  # _TriggerSoon is a guarded version of trigger that can accumulate changes.
  # This means that even if you're a bad person and call `persistModel` 100 times
  # from 100 task objects queued at the same time, it will only create one
  # `trigger` event. This is important since the database triggering impacts
  # the entire application.
  _triggerSoon: (change) =>
    @_triggerPromise ?= new Promise (resolve, reject) =>
      @_resolve = resolve

    flush = =>
      return unless @_changeAccumulated
      clearTimeout(@_changeFireTimer) if @_changeFireTimer
      @trigger(@_changeAccumulated)
      @_changeAccumulated = null
      @_changeFireTimer = null
      @_resolve?()
      @_triggerPromise = null

    set = (change) =>
      clearTimeout(@_changeFireTimer) if @_changeFireTimer
      @_changeAccumulated = change
      @_changeFireTimer = setTimeout(flush, 20)

    concat = (change) =>
      @_changeAccumulated.objects.push(change.objects...)

    if not @_changeAccumulated
      set(change)
    else if @_changeAccumulated.objectClass is change.objectClass and @_changeAccumulated.type is change.type
      concat(change)
    else
      flush()
      set(change)

    return @_triggerPromise

  # Fires the queries required to write models to the DB
  #
  # Returns a promise that:
  #   - resolves when all write queries are complete
  #   - rejects if any query fails
  _writeModels: (models) =>
    promises = []

    # IMPORTANT: This method assumes that all the models you
    # provide are of the same class, and have different ids!

    # Avoid trying to write too many objects a time - sqlite can only handle
    # value sets `(?,?)...` of less than SQLITE_MAX_COMPOUND_SELECT (500),
    # and we don't know ahead of time whether we'll hit that or not.
    if models.length > 50
      return Promise.all([
        @_writeModels(models[0..49])
        @_writeModels(models[50..models.length])
      ])

    klass = models[0].constructor
    attributes = _.values(klass.attributes)
    ids = []

    columnAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr.columnSQL && attr.jsonKey != 'id'

    # Compute the columns in the model table and a question mark string
    columns = ['id', 'data']
    marks = ['?', '?']
    columnAttributes.forEach (attr) ->
      columns.push(attr.jsonKey)
      marks.push('?')
    columnsSQL = columns.join(',')
    marksSet = "(#{marks.join(',')})"

    # Prepare a batch insert VALUES (?,?,?), (?,?,?)... by assembling
    # an array of the values and a corresponding question mark set
    values = []
    marks = []
    for model in models
      json = model.toJSON(joined: false)
      ids.push(model.id)
      values.push(model.id, JSON.stringify(json))
      columnAttributes.forEach (attr) ->
        values.push(json[attr.jsonKey])
      marks.push(marksSet)

    marksSQL = marks.join(',')
    promises.push @_query("REPLACE INTO `#{klass.name}` (#{columnsSQL}) VALUES #{marksSQL}", values)

    # For each join table property, find all the items in the join table for this
    # model and delte them. Insert each new value back into the table.
    collectionAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection

    collectionAttributes.forEach (attr) =>
      joinTable = tableNameForJoin(klass, attr.itemClass)

      promises.push @_query("DELETE FROM `#{joinTable}` WHERE `id` IN ('#{ids.join("','")}')")

      joinMarks = []
      joinedValues = []
      for model in models
        joinedModels = model[attr.modelKey]
        if joinedModels
          for joined in joinedModels
            joinMarks.push('(?,?)')
            joinedValues.push(model.id, joined.id)

      unless joinedValues.length is 0
        # Write no more than 200 items (400 values) at once to avoid sqlite limits
        # 399 values: slices:[0..0]
        # 400 values: slices:[0..0]
        # 401 values: slices:[0..1]
        slicePageCount = Math.ceil(joinedValues.length / 400) - 1
        for slice in [0..slicePageCount] by 1
          [ms, me] = [slice*200, slice*200 + 199]
          [vs, ve] = [slice*400, slice*400 + 399]
          promises.push @_query("INSERT OR IGNORE INTO `#{joinTable}` (`id`, `value`) VALUES #{joinMarks[ms..me].join(',')}", joinedValues[vs..ve])

    # For each joined data property stored in another table...
    values = []
    marks = []
    joinedDataAttributes = _.filter attributes, (attr) ->
      attr instanceof AttributeJoinedData

    joinedDataAttributes.forEach (attr) =>
      for model in models
        if model[attr.modelKey]?
          promises.push @_query("REPLACE INTO `#{attr.modelTable}` (`id`, `value`) VALUES (?, ?)", [model.id, model[attr.modelKey]])

    # For each model, execute any other code the model wants to run.
    # This allows model classes to do things like update a full-text table
    # that holds a composite of several fields
    if klass.additionalSQLiteConfig?.writeModel?
      for model in models
        promises = promises.concat klass.additionalSQLiteConfig.writeModel(model)

    return Promise.all(promises)

  # Fires the queries required to delete models to the DB
  #
  # Returns a promise that:
  #   - resolves when all deltion queries are complete
  #   - rejects if any query fails
  _deleteModel: (model) =>
    promises = []

    klass = model.constructor
    attributes = _.values(klass.attributes)

    # Delete the primary record
    promises.push @_query("DELETE FROM `#{klass.name}` WHERE `id` = ?", [model.id])

    # For each join table property, find all the items in the join table for this
    # model and delte them. Insert each new value back into the table.
    collectionAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection

    collectionAttributes.forEach (attr) =>
      joinTable = tableNameForJoin(klass, attr.itemClass)
      promises.push @_query("DELETE FROM `#{joinTable}` WHERE `id` = ?", [model.id])

    joinedDataAttributes = _.filter attributes, (attr) ->
      attr instanceof AttributeJoinedData

    joinedDataAttributes.forEach (attr) =>
      promises.push @_query("DELETE FROM `#{attr.modelTable}` WHERE `id` = ?", [model.id])

    # Execute any other code the model wants to run.
    # This allows model classes to do things like update a full-text table
    # that holds a composite of several fields, or update entirely
    # separate database systems
    promises = promises.concat klass.additionalSQLiteConfig?.deleteModel?(model)

    return Promise.all(promises)


module.exports = new DatabaseStore()
