Reflux = require 'reflux'
async = require 'async'
remote = require 'remote'
_ = require 'underscore-plus'
Actions = require '../actions'
Model = require '../models/model'
LocalLink = require '../models/local-link'
ModelQuery = require '../models/query'
{AttributeCollection} = require '../attributes'
{modelFromJSON, modelClassMap, tableNameForJoin, generateTempId, isTempId} = require '../models/utils'
fs = require 'fs-plus'
path = require 'path'
exec = require('child_process').exec
ipc = require 'ipc'

silent = atom.getLoadSettings().isSpec
verbose = false

# DatabaseConnection is a small shim for making database queries. Queries
# are actually executed in the Browser process and eventually, we'll move
# more and more of this class there.
class DatabaseProxy
  constructor: (@databasePath) ->
    @windowId = remote.getCurrentWindow().id
    @queryCallbacks = {}
    @queryId = 0

    ipc.on 'database-result', ({queryKey, err, result}) =>
      @queryCallbacks[queryKey](err, result) if @queryCallbacks[queryKey]
      delete @queryCallbacks[queryKey]

    @

  query: (query, values, callback) ->
    @queryId += 1
    queryKey = "#{@windowId}-#{@queryId}"
    @queryCallbacks[queryKey] = callback if callback
    ipc.send('database-query', {@databasePath, queryKey, query, values})

# DatabasePromiseTransaction converts the callback syntax of the Database
# into a promise syntax with nice features like serial execution of many
# queries in the same promise.
class DatabasePromiseTransaction
  constructor: (@_db, @_resolve, @_reject) ->
    @_running = 0

  execute: (query, values, querySuccess, queryFailure) ->
    # Wrap any user-provided success callback in one that checks query time
    callback = (err, result) =>
      if err
        console.log("Query #{query}, #{JSON.stringify(values)} failed #{err.message}")
        queryFailure(err) if queryFailure
        @_reject(err)
      else
        querySuccess(result) if querySuccess

      # The user can attach things to the finish promise to run code after
      # the completion of all pending queries in the transaction. We fire
      # the resolve function after a delay because we need to wait for the
      # transaction to be GC'd and give up it's lock
      @_running -= 1
      if @_running == 0
        @_resolve(result)

    @_running += 1
    @_db.query(query, values || [], callback)

  executeInSeries: (queries) ->
    async.eachSeries queries
    , (query, callback) =>
      @execute(query, [], -> callback())
    , (err) =>
      @_resolve()


DatabaseStore = Reflux.createStore
  init: ->
    @_root = (atom.state.mode == 'editor')
    @_localIdLookupCache = {}
    @_dbPath = path.join(atom.getConfigDirPath(),'edgehill.db')
    @_db = null

    # Setup the database tables
    _.defer => @openDatabase({createTables: @_root})

    if @_root
      @listenTo(Actions.logout, @onLogout)

  inTransaction: (options = {}, callback) ->
    new Promise (resolve, reject) =>
      aquire = =>
        db = @_db || options.database
        return setTimeout(aquire, 50) unless db
        callback(new DatabasePromiseTransaction(db, resolve, reject))
      aquire()

  forEachClass: (callback) ->
    classMap = modelClassMap()
    for key, klass of classMap
      callback(klass) if klass.attributes

  openDatabase: (options = {createTables: false}) ->
    app = remote.getGlobal('atomApplication')
    app.prepareDatabase @_dbPath, =>
      database = new DatabaseProxy(@_dbPath)

      console.log('CREATE TABLES IS')
      console.log(options.createTables)
      if options.createTables
        # Initialize the database and setup our schema. Note that we try to do this every
        # time right now and just do `IF NOT EXISTS`. In the future we need much better migration
        # support.
        @inTransaction {database: database}, (tx) =>
          tx.execute('PRAGMA journal_mode=WAL;')
          queries = []
          @forEachClass (klass) =>
            queries = queries.concat(@queriesForTableSetup(klass))
          tx.executeInSeries(queries)
        .then =>
          @_db = database
        .catch ->
          # An error occured - most likely a schema change. Log the user out so the
          # database is compeltely reset.
          atom.logout()
      else
        @_db = database

  teardownDatabase: (callback) ->
    app = remote.getGlobal('atomApplication')
    app.teardownDatabase @_dbPath, =>
      @_db = null
      @trigger({})
      callback()

  writeModels: (tx, models) ->
    # IMPORTANT: This method assumes that all the models you
    # provide are of the same class!

    # Avoid trying to write too many objects a time - sqlite can only handle
    # value sets `(?,?)...` of less than SQLITE_MAX_COMPOUND_SELECT (500),
    # and we don't know ahead of time whether we'll hit that or not.
    if models.length > 100
      @writeModels(tx, models[0..99])
      @writeModels(tx, models[100..models.length])
      return

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
      json = model.toJSON()
      ids.push(model.id)
      values.push(model.id, JSON.stringify(json))
      columnAttributes.forEach (attr) ->
        values.push(json[attr.jsonKey])
      marks.push(marksSet)

    marksSQL = marks.join(',')
    tx.execute("REPLACE INTO `#{klass.name}` (#{columnsSQL}) VALUES #{marksSQL}", values)

    # For each join table property, find all the items in the join table for this
    # model and delte them. Insert each new value back into the table.
    joinAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection

    joinAttributes.forEach (attr) ->
      joinTable = tableNameForJoin(klass, attr.itemClass)

      joinMarks = []
      joinedValues = []
      for model in models
        joinedModels = model[attr.modelKey]
        if joinedModels
          for joined in joinedModels
            joinMarks.push('(?,?)')
            joinedValues.push(model.id, joined.id)
      tx.execute("DELETE FROM `#{joinTable}` WHERE `id` IN ('#{ids.join("','")}')")

      unless joinedValues.length is 0
        # Write no more than 200 items (400 values) at once to avoid sqlite limits
        for slice in [0..Math.floor(joinedValues.length / 400)] by 1
          [ms, me] = [slice*200, slice*200 + 199]
          [vs, ve] = [slice*400, slice*400 + 399]
          tx.execute("INSERT INTO `#{joinTable}` (`id`, `value`) VALUES #{joinMarks[ms..me].join(',')}", joinedValues[vs..ve])

  deleteModel: (tx, model) ->
    klass = model.constructor
    attributes = _.values(klass.attributes)

    # Delete the primary record
    tx.execute("DELETE FROM `#{klass.name}` WHERE `id` = ?", [model.id])

    # For each join table property, find all the items in the join table for this
    # model and delte them. Insert each new value back into the table.
    joinAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection

    joinAttributes.forEach (attr) ->
      joinTable = tableNameForJoin(klass, attr.itemClass)
      tx.execute("DELETE FROM `#{joinTable}` WHERE `id` = ?", [model.id])

  # Inbound Events

  onLogout: ->
    @teardownDatabase =>
      @openDatabase({createTables: @_root})

  persistModel: (model) ->
    @inTransaction {}, (tx) =>
      tx.execute('BEGIN TRANSACTION')
      @writeModels(tx, [model])
      tx.execute('COMMIT')
      @trigger({objectClass: model.constructor.name, objects: [model]})

  persistModels: (models) ->
    klass = models[0].constructor
    @inTransaction {}, (tx) =>
      tx.execute('BEGIN TRANSACTION')
      for model in models
        unless model.constructor == klass
          throw new Error "When you batch persist objects, they must be of the same type"
      @writeModels(tx, models)
      tx.execute('COMMIT')
      @trigger({objectClass: models[0].constructor.name, objects: models})

  unpersistModel: (model) ->
    @inTransaction {}, (tx) =>
      tx.execute('BEGIN TRANSACTION')
      @deleteModel(tx, model)
      tx.execute('COMMIT')
      @trigger({objectClass: model.constructor.name, objects: [model]})

  swapModel: ({oldModel, newModel, localId}) ->
    @inTransaction {}, (tx) =>
      tx.execute('BEGIN TRANSACTION')
      @deleteModel(tx, oldModel)
      @writeModels(tx, [newModel])
      @writeModels(tx, [new LocalLink(id: localId, objectId: newModel.id)]) if localId
      tx.execute('COMMIT')
      @trigger({objectClass: newModel.constructor.name, objects: [oldModel, newModel]})
      Actions.didSwapModel({oldModel, newModel, localId})

  # ActiveRecord-style Querying

  find: (klass, id) ->
    throw (new Error "find takes a string Id. You may have intended to use findBy.") unless _.isString(id)
    new ModelQuery(klass, @).where({id:id}).one()

  findBy: (klass, predicates = []) ->
    new ModelQuery(klass, @).where(predicates).one()

  findAll: (klass, predicates = []) ->
    new ModelQuery(klass, @).where(predicates)

  count: (klass, predicates = []) ->
    new ModelQuery(klass, @).where(predicates).count()

  # Support for Local IDs

  findByLocalId: (klass, localId) ->
    new Promise (resolve, reject) =>
      @find(LocalLink, localId).then (link) =>
        return reject("Find by local ID lookup failed") unless link
        @find(klass, link.objectId).then(resolve)

  bindToLocalId: (model, localId) ->
    new Promise (resolve, reject) =>
      console.log("Binding model id #{model.id} to localId #{localId}")
      unless localId
        if isTempId(model.id)
          localId = model.id
        else
          localId = generateTempId()

      link = new LocalLink({id: localId, objectId: model.id})
      console.log("Bound model id #{model.id} to localId #{localId}")
      @persistModel(link).then ->
        resolve(localId)
      .catch(reject)

  localIdForModel: (model) ->
    new Promise (resolve, reject) =>
      if @_localIdLookupCache[model.id]
        resolve(@_localIdLookupCache[model.id])
        return

      @findBy(LocalLink, {objectId: model.id}).then (link) =>
        if link
          @_localIdLookupCache[model.id] = link.id
          resolve(link.id)
        else
          @bindToLocalId(model).then (localId) =>
            @_localIdLookupCache[model.id] = localId
            resolve(localId)
          .catch(reject)

  # Heavy Lifting

  run: (modelQuery) ->
    @inTransaction {readonly: true}, (tx) ->
      tx.execute modelQuery.sql(), []
    .then (result) ->
      Promise.resolve(modelQuery.formatResult(result))

  queriesForTableSetup: (klass) ->
    attributes = _.values(klass.attributes)
    queries = []

    # Identify attributes of this class that can be matched against. These
    # attributes need their own columns in the table
    columnAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr.columnSQL && attr.jsonKey != 'id'

    columns = ['id TEXT PRIMARY KEY', 'data BLOB']
    columnAttributes.forEach (attr) ->
      columns.push(attr.columnSQL())
      queries.push("CREATE INDEX IF NOT EXISTS `#{klass.name}-#{attr.jsonKey}` ON `#{klass.name}` (`#{attr.jsonKey}`)")

    columnsSQL = columns.join(',')
    queries.unshift("CREATE TABLE IF NOT EXISTS `#{klass.name}` (#{columnsSQL})")
    queries.push("CREATE INDEX IF NOT EXISTS `#{klass.name}-id` ON `#{klass.name}` (`id`)")

    # Identify collection attributes that can be matched against. These require
    # JOIN tables. (Right now the only one of these is Thread.tags)
    joinAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection
    joinAttributes.forEach (attribute) ->
      joinTable = tableNameForJoin(klass, attribute.itemClass)
      queries.push("CREATE TABLE IF NOT EXISTS `#{joinTable}` (id TEXT KEY, `value` TEXT)")
      queries.push("CREATE INDEX IF NOT EXISTS `#{joinTable}-id-val` ON `#{joinTable}` (`id`,`value`)")

    queries


module.exports = DatabaseStore
