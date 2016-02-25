_ = require 'underscore'
Model = require '../models/model'
Utils = require '../models/utils'

{AttributeCollection, AttributeJoinedData} = require '../attributes'
{tableNameForJoin} = require '../models/utils'

class DatabaseTransaction
  constructor: (@database) ->
    @_changeRecords = []
    @_opened = false

  find: (args...) => @database.find(args...)
  findBy: (args...) => @database.findBy(args...)
  findAll: (args...) => @database.findAll(args...)
  modelify: (args...) => @database.modelify(args...)
  count: (args...) => @database.count(args...)
  findJSONBlob: (args...) => @database.findJSONBlob(args...)

  execute: (fn) =>
    if @_opened
      throw new Error("DatabaseTransaction:execute was already called")
    start = Date.now()
    @_query("BEGIN IMMEDIATE TRANSACTION")
    .then =>
      @_opened = true
      fn(@)
    .finally =>
      if @_opened
        @_opened = false
        @_query("COMMIT")
        .then =>
          for record in @_changeRecords
            @database.accumulateAndTrigger(record)

  # Mutating the Database

  persistJSONBlob: (id, json) ->
    JSONBlob = require '../models/json-blob'
    @persistModel(new JSONBlob({id, json}))

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
    unless model and model instanceof Model
      throw new Error("DatabaseTransaction::persistModel - You must pass an instance of the Model class.")
    @persistModels([model])

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
  persistModels: (models=[], {}) =>
    return Promise.resolve() if models.length is 0

    klass = models[0].constructor
    clones = []
    ids = {}

    unless models[0] instanceof Model
      throw new Error("DatabaseTransaction::persistModels - You must pass an array of items which descend from the Model class.")

    for model in models
      unless model and model.constructor is klass
        throw new Error("DatabaseTransaction::persistModels - When you batch persist objects, they must be of the same type")
      if ids[model.id]
        throw new Error("DatabaseTransaction::persistModels - You must pass an array of models with different ids. ID #{model.id} is in the set multiple times.")

      clones.push(model.clone())
      ids[model.id] = true

    # Note: It's important that we clone the objects since other code could mutate
    # them during the save process. We want to guaruntee that the models you send to
    # persistModels are saved exactly as they were sent.
    metadata =
      objectClass: clones[0].constructor.name
      objectIds: Object.keys(ids)
      objects: clones
      type: 'persist'

    @_runMutationHooks('beforeDatabaseChange', metadata).then (data) =>
      @_writeModels(clones).then =>
        @_runMutationHooks('afterDatabaseChange', metadata, data)
        @_changeRecords.push(metadata)

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
    model = model.clone()
    metadata =
      objectClass: model.constructor.name,
      objectIds: [model.id]
      objects: [model],
      type: 'unpersist'

    @_runMutationHooks('beforeDatabaseChange', metadata).then (data) =>
      @_deleteModel(model).then =>
        @_runMutationHooks('afterDatabaseChange', metadata, data)
        @_changeRecords.push(metadata)

  ########################################################################
  ########################### PRIVATE METHODS ############################
  ########################################################################

  _query: =>
    @database._query(arguments...)

  _runMutationHooks: (selectorName, metadata, data = []) =>
    beforePromises = @database.mutationHooks().map (hook, idx) =>
      Promise.try =>
        hook[selectorName](@_query, metadata, data[idx])

    Promise.all(beforePromises).catch (e) =>
      unless NylasEnv.inSpecMode()
        console.warn("DatabaseTransaction Hook: #{selectorName} failed", e)
      Promise.resolve([])

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
    ids = []
    for model in models
      json = model.toJSON(joined: false)
      ids.push(model.id)
      values.push(model.id, JSON.stringify(json, Utils.registeredObjectReplacer))
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

    return Promise.all(promises)

module.exports = DatabaseTransaction
