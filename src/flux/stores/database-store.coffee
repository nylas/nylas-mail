_ = require 'underscore'
async = require 'async'
path = require 'path'
fs = require 'fs'
sqlite3 = require 'sqlite3'
Model = require '../models/model'
Utils = require '../models/utils'
Actions = require '../actions'
ModelQuery = require '../models/query'
NylasStore = require '../../global/nylas-store'
PromiseQueue = require 'promise-queue'
PriorityUICoordinator = require '../../priority-ui-coordinator'
DatabaseSetupQueryBuilder = require './database-setup-query-builder'
DatabaseChangeRecord = require './database-change-record'
DatabaseTransaction = require './database-transaction'
JSONBlob = null

{remote, ipcRenderer} = require 'electron'

DatabaseVersion = 24
DatabasePhase =
  Setup: 'setup'
  Ready: 'ready'
  Close: 'close'

DEBUG_TO_LOG = false
DEBUG_QUERY_PLANS = NylasEnv.inDevMode()

BEGIN_TRANSACTION = 'BEGIN TRANSACTION'
COMMIT = 'COMMIT'

TXINDEX = 0

class JSONBlobQuery extends ModelQuery
  formatResult: (objects) =>
    return objects[0]?.json || null



###
Public: N1 is built on top of a custom database layer modeled after
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
    @_inflightTransactions = 0
    @_open = false
    @_waiting = []

    @setupEmitter()
    @_emitter.setMaxListeners(100)

    if NylasEnv.inSpecMode()
      @_databasePath = path.join(NylasEnv.getConfigDirPath(),'edgehill.test.db')
    else
      @_databasePath = path.join(NylasEnv.getConfigDirPath(),'edgehill.db')

    @_databaseMutationHooks = []

    # Listen to events from the application telling us when the database is ready,
    # should be closed so it can be deleted, etc.
    ipcRenderer.on('database-phase-change', @_onPhaseChange)
    _.defer => @_onPhaseChange()

  _onPhaseChange: (event) =>
    return if NylasEnv.inSpecMode()

    app = remote.getGlobal('application')
    phase = app.databasePhase()

    if phase is DatabasePhase.Setup and NylasEnv.isWorkWindow()
      @_openDatabase =>
        @_checkDatabaseVersion {allowNotSet: true}, =>
          @_runDatabaseSetup =>
            app.setDatabasePhase(DatabasePhase.Ready)
            setTimeout(@_runDatabaseAnalyze, 60 * 1000)

    else if phase is DatabasePhase.Ready
      @_openDatabase =>
        @_checkDatabaseVersion {}, =>
          @_open = true
          w() for w in @_waiting
          @_waiting = []

    else if phase is DatabasePhase.Close
      @_open = false
      @_db?.close()
      @_db = null

  # When 3rd party components register new models, we need to refresh the
  # database schema to prepare those tables. This method may be called
  # extremely frequently as new models are added when packages load.
  refreshDatabaseSchema: ->
    return unless NylasEnv.isWorkWindow()
    app = remote.getGlobal('application')
    phase = app.databasePhase()
    if phase isnt DatabasePhase.Setup
      app.setDatabasePhase(DatabasePhase.Setup)

  _openDatabase: (ready) =>
    return ready() if @_db

    if NylasEnv.isWorkWindow()
      # Since only the main window calls `_runDatabaseSetup`, it's important that
      # it is also the only window with permission to create the file on disk
      mode = sqlite3.OPEN_READWRITE | sqlite3.OPEN_CREATE
    else
      mode = sqlite3.OPEN_READWRITE

    @_db = new sqlite3.Database @_databasePath, mode, (err) =>
      return @_handleSetupError(err) if err

      # https://www.sqlite.org/wal.html
      # WAL provides more concurrency as readers do not block writers and a writer
      # does not block readers. Reading and writing can proceed concurrently.
      @_db.run("PRAGMA journal_mode = WAL;")

      # Note: These are properties of the connection, so they must be set regardless
      # of whether the database setup queries are run.

      # https://www.sqlite.org/intern-v-extern-blob.html
      # A database page size of 8192 or 16384 gives the best performance for large BLOB I/O.
      @_db.run("PRAGMA main.page_size = 8192;")
      @_db.run("PRAGMA main.cache_size = 20000;")
      @_db.run("PRAGMA main.synchronous = NORMAL;")
      @_db.configure('busyTimeout', 10000)
      @_db.on 'profile', (query, msec) =>
        if msec > 100
          @_prettyConsoleLog("#{msec}msec: #{query}")
        else
          console.debug(DEBUG_TO_LOG, "#{msec}: #{query}")

      ready()

  _checkDatabaseVersion: ({allowNotSet} = {}, ready) =>
    @_db.get 'PRAGMA user_version', (err, {user_version}) =>
      return @_handleSetupError(err) if err
      emptyVersion = user_version is 0
      wrongVersion = user_version/1 isnt DatabaseVersion
      if wrongVersion and not (emptyVersion and allowNotSet)
        return @_handleSetupError(new Error("Incorrect database schema version: #{user_version} not #{DatabaseVersion}"))
      ready()

  _runDatabaseSetup: (ready) =>
    builder = new DatabaseSetupQueryBuilder()

    @_db.serialize =>
      async.each builder.setupQueries(), (query, callback) =>
        console.debug(DEBUG_TO_LOG, "DatabaseStore: #{query}")
        @_db.run(query, [], callback)
      , (err) =>
        return @_handleSetupError(err) if err
        @_db.run "PRAGMA user_version=#{DatabaseVersion}", (err) =>
          return @_handleSetupError(err) if err

          exportPath = path.join(NylasEnv.getConfigDirPath(), 'mail-rules-export.json')
          if fs.existsSync(exportPath)
            try
              row = JSON.parse(fs.readFileSync(exportPath))
              @inTransaction (t) -> t.persistJSONBlob('MailRules-V2', row['json'])
              fs.unlink(exportPath)
            catch err
              console.log("Could not re-import mail rules: #{err}")
          ready()

  _runDatabaseAnalyze: =>
    builder = new DatabaseSetupQueryBuilder()
    async.each builder.analyzeQueries(), (query, callback) =>
      @_db.run(query, [], callback)
    , (err) =>
      console.log("Completed ANALYZE of database")

  _handleSetupError: (err = (new Error("Manually called _handleSetupError"))) =>
    NylasEnv.reportError(err, {}, noWindows: true)

    # Temporary: export mail rules. They're the only bit of data in the cache
    # we can't rebuild. Should be moved to cloud metadata store soon.
    @_db.all "SELECT * FROM JSONBlob WHERE id = 'MailRules-V2' LIMIT 1", [], (mailsRulesErr, results = []) =>
      if not mailsRulesErr and results.length is 1
        exportPath = path.join(NylasEnv.getConfigDirPath(), 'mail-rules-export.json')
        try
          fs.writeFileSync(exportPath, results[0]['data'])
        catch writeErr
          console.log("Could not write mail rules to file: #{writeErr}")

      app = require('electron').remote.getGlobal('application')
      app.rebuildDatabase()

  _prettyConsoleLog: (q) =>
    q = "color:black |||%c " + q
    q = q.replace(/`(\w+)`/g, "||| color:purple |||%c$&||| color:black |||%c")

    colorRules =
      'color:green': ['SELECT', 'INSERT INTO', 'VALUES', 'WHERE', 'FROM', 'JOIN', 'ORDER BY', 'DESC', 'ASC', 'INNER', 'OUTER', 'LIMIT', 'OFFSET', 'IN']
      'color:red; background-color:#ffdddd;': ['SCAN TABLE']

    for style, keywords of colorRules
      for keyword in keywords
        q = q.replace(new RegExp("\\b#{keyword}\\b", 'g'), "||| #{style} |||%c#{keyword}||| color:black |||%c")

    q = q.split('|||')
    colors = []
    msg = []
    for i in [0...q.length]
      if i % 2 is 0
        colors.push(q[i])
      else
        msg.push(q[i])

    console.log(msg.join(''), colors...)


  # Returns a promise that resolves when the query has been completed and
  # rejects when the query has failed.
  #
  # If a query is made while the connection is being setup, the
  # DatabaseConnection will queue the queries and fire them after it has
  # been setup. The Promise returned here wont resolve until that happens
  _query: (query, values=[]) =>
    new Promise (resolve, reject) =>
      if not @_open
        @_waiting.push => @_query(query, values).then(resolve, reject)
        return

      if query.indexOf("SELECT ") is 0
        fn = 'all'
      else
        fn = 'run'

      if query.indexOf("SELECT ") is 0
        if DEBUG_QUERY_PLANS
          @_db.all "EXPLAIN QUERY PLAN #{query}", values, (err, results=[]) =>
            str = results.map((row) -> row.detail).join('\n') + " for " + query
            return if str.indexOf('ThreadCounts') > 0
            return if str.indexOf('ThreadSearch') > 0
            if str.indexOf('SCAN') isnt -1 and str.indexOf('COVERING INDEX') is -1
              @_prettyConsoleLog(str)

      # Important: once the user begins a transaction, queries need to run
      # in serial.  This ensures that the subsequent "COMMIT" call
      # actually runs after the other queries in the transaction, and that
      # no other code can execute "BEGIN TRANS." until the previously
      # queued BEGIN/COMMIT have been processed.

      # We don't exit serial execution mode until the last pending transaction has
      # finished executing.

      if query.indexOf "BEGIN" is 0
        @_db.serialize() if @_inflightTransactions is 0
        @_inflightTransactions += 1

      @_db[fn] query, values, (err, results) =>
        if err
          console.error("DatabaseStore: Query #{query}, #{JSON.stringify(values)} failed #{err.toString()}")

        if query is COMMIT
          @_inflightTransactions -= 1
          @_db.parallelize() if @_inflightTransactions is 0

        return reject(err) if err
        return resolve(results)

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
    throw new Error("DatabaseStore::find - You must provide a class") unless klass
    throw new Error("DatabaseStore::find - You must provide a string id. You may have intended to use findBy.") unless _.isString(id)
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
    throw new Error("DatabaseStore::findBy - You must provide a class") unless klass
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
    throw new Error("DatabaseStore::findAll - You must provide a class") unless klass
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
    throw new Error("DatabaseStore::count - You must provide a class") unless klass
    new ModelQuery(klass, @).where(predicates).count()

  # Public: Modelify converts the provided array of IDs or models (or a mix of
  # IDs and models) into an array of models of the `klass` provided by querying for the missing items.
  #
  # Modelify is efficient and uses a single database query. It resolves Immediately
  # if no query is necessary.
  #
  # - `class` The {Model} class desired.
  # - 'arr' An {Array} with a mix of string model IDs and/or models.
  #
  modelify: (klass, arr) =>
    if not _.isArray(arr) or arr.length is 0
      return Promise.resolve([])

    ids = []
    clientIds = []
    for item in arr
      if item instanceof klass
        if not item.serverId
          clientIds.push(item.clientId)
        else
          continue
      else if _.isString(item)
        if Utils.isTempId(item)
          clientIds.push(item)
        else
          ids.push(item)
      else
        throw new Error("modelify: Not sure how to convert #{item} into a #{klass.name}")

    if ids.length is 0 and clientIds.length is 0
      return Promise.resolve(arr)

    queries =
      modelsFromIds: []
      modelsFromClientIds: []

    if ids.length
      queries.modelsFromIds = @findAll(klass).where(klass.attributes.id.in(ids))
    if clientIds.length
      queries.modelsFromClientIds = @findAll(klass).where(klass.attributes.clientId.in(clientIds))

    Promise.props(queries).then ({modelsFromIds, modelsFromClientIds}) =>
      modelsByString = {}
      modelsByString[model.id] = model for model in modelsFromIds
      modelsByString[model.clientId] = model for model in modelsFromClientIds

      arr = arr.map (item) ->
        if item instanceof klass
          return item
        else
          return modelsByString[item]

      return Promise.resolve(arr)

  # Public: Executes a {ModelQuery} on the local database.
  #
  # - `modelQuery` A {ModelQuery} to execute.
  #
  # Returns a {Promise} that
  #   - resolves with the result of the database query.
  #
  run: (modelQuery, options = {format: true}) =>
    @_query(modelQuery.sql(), []).then (result) =>
      result = modelQuery.inflateResult(result)
      result = modelQuery.formatResult(result) unless options.format is false
      Promise.resolve(result)

  findJSONBlob: (id) ->
    JSONBlob ?= require '../models/json-blob'
    new JSONBlobQuery(JSONBlob, @).where({id}).one()

  # Private: Mutation hooks allow you to observe changes to the database and
  # add additional functionality before and after the REPLACE / INSERT queries.
  #
  # beforeDatabaseChange: Run queries, etc. and return a promise. The DatabaseStore
  # will proceed with changes once your promise has finished. You cannot call
  # persistModel or unpersistModel from this hook.
  #
  # afterDatabaseChange: Run queries, etc. after the REPLACE / INSERT queries
  #
  # Warning: this is very low level. If you just want to watch for changes, You
  # should subscribe to the DatabaseStore's trigger events.
  #
  addMutationHook: ({beforeDatabaseChange, afterDatabaseChange}) ->
    throw new Error("DatabaseStore:addMutationHook - You must provide a beforeDatabaseChange function") unless beforeDatabaseChange
    throw new Error("DatabaseStore:addMutationHook - You must provide a afterDatabaseChange function") unless afterDatabaseChange
    @_databaseMutationHooks.push({beforeDatabaseChange, afterDatabaseChange})

  removeMutationHook: (hook) ->
    @_databaseMutationHooks = _.without(@_databaseMutationHooks, hook)

  mutationHooks: ->
    @_databaseMutationHooks


  # Public: Opens a new database transaction for writing changes.
  # DatabaseStore.inTransacion makes the following guarantees:
  #
  # - No other calls to `inTransaction` will run until the promise has finished.
  #
  # - No other process will be able to write to sqlite while the provided function
  #   is running. "BEGIN IMMEDIATE TRANSACTION" semantics are:
  #     + No other connection will be able to write any changes.
  #     + Other connections can read from the database, but they will not see
  #       pending changes.
  #
  # @param fn {function} callback that will be executed inside a database transaction
  # Returns a {Promise} that resolves when the transaction has successfully
  # completed.
  inTransaction: (fn) ->
    t = new DatabaseTransaction(@)
    @_transactionQueue ?= new PromiseQueue(1, Infinity)
    @_transactionQueue.add ->
      t.execute(fn)

  # _accumulateAndTrigger is a guarded version of trigger that can accumulate changes.
  # This means that even if you're a bad person and call `persistModel` 100 times
  # from 100 task objects queued at the same time, it will only create one
  # `trigger` event. This is important since the database triggering impacts
  # the entire application.
  accumulateAndTrigger: (change) =>
    @_triggerPromise ?= new Promise (resolve, reject) =>
      @_resolve = resolve

    flush = =>
      return unless @_changeAccumulated
      clearTimeout(@_changeFireTimer) if @_changeFireTimer
      @trigger(new DatabaseChangeRecord(@_changeAccumulated))
      @_changeAccumulated = null
      @_changeAccumulatedLookup = null
      @_changeFireTimer = null
      @_resolve?()
      @_triggerPromise = null

    set = (change) =>
      clearTimeout(@_changeFireTimer) if @_changeFireTimer
      @_changeAccumulated = change
      @_changeAccumulatedLookup = {}
      for obj, idx in @_changeAccumulated.objects
        @_changeAccumulatedLookup[obj.id] = idx
      @_changeFireTimer = setTimeout(flush, 10)

    concat = (change) =>
      # When we join new models into our set, replace existing ones so the same
      # model cannot exist in the change record set multiple times.
      for obj in change.objects
        idx = @_changeAccumulatedLookup[obj.id]
        if idx
          @_changeAccumulated.objects[idx] = obj
        else
          @_changeAccumulatedLookup[obj.id] = @_changeAccumulated.objects.length
          @_changeAccumulated.objects.push(obj)

    if not @_changeAccumulated
      set(change)
    else if @_changeAccumulated.objectClass is change.objectClass and @_changeAccumulated.type is change.type
      concat(change)
    else
      flush()
      set(change)

    return @_triggerPromise


  # Search Index Operations

  createSearchIndexSql: (klass) =>
    throw new Error("DatabaseStore::createSearchIndex - You must provide a class") unless klass
    throw new Error("DatabaseStore::createSearchIndex - #{klass.name} must expose an array of `searchFields`") unless klass
    searchTableName = "#{klass.name}Search"
    searchFields = klass.searchFields
    return (
      "CREATE VIRTUAL TABLE IF NOT EXISTS `#{searchTableName}` " +
      "USING fts5(
        tokenize='porter unicode61',
        content_id UNINDEXED,
        #{searchFields.join(', ')}
      )"
    )

  createSearchIndex: (klass) =>
    sql = @createSearchIndexSql(klass)
    @_query(sql)

  searchIndexSize: (klass) =>
    searchTableName = "#{klass.name}Search"
    sql = "SELECT COUNT(content_id) as count FROM `#{searchTableName}`"
    return @_query(sql).then((result) => result[0].count)

  isIndexEmptyForAccount: (accountId, modelKlass) =>
    modelTable = modelKlass.name
    searchTable = "#{modelTable}Search"
    sql = (
      "SELECT `#{searchTable}`.`content_id` FROM `#{searchTable}` INNER JOIN `#{modelTable}`
      ON `#{modelTable}`.id = `#{searchTable}`.`content_id` WHERE `#{modelTable}`.`account_id` = ?
      LIMIT 1"
    )
    return @_query(sql, [accountId]).then((result) => result.length is 0)

  dropSearchIndex: (klass) =>
    throw new Error("DatabaseStore::createSearchIndex - You must provide a class") unless klass
    searchTableName = "#{klass.name}Search"
    sql = "DROP TABLE IF EXISTS `#{searchTableName}`"
    @_query(sql)

  isModelIndexed: (model, isIndexed) =>
    return Promise.resolve(true) if isIndexed is true
    searchTableName = "#{model.constructor.name}Search"
    exists = (
      "SELECT rowid FROM `#{searchTableName}` WHERE `#{searchTableName}`.`content_id` = ?"
    )
    return @_query(exists, [model.id]).then((results) =>
      return Promise.resolve(results.length > 0)
    )

  indexModel: (model, indexData, isModelIndexed) =>
    searchTableName = "#{model.constructor.name}Search"
    @isModelIndexed(model, isModelIndexed)
    .then((isIndexed) =>
      if (isIndexed)
        return @updateModelIndex(model, indexData, isIndexed)

      indexFields = Object.keys(indexData)
      keysSql = 'content_id, ' + indexFields.join(", ")
      valsSql = '?, ' + indexFields.map(=> '?').join(", ")
      values = [model.id].concat(indexFields.map((k) => indexData[k]))
      sql = (
        "INSERT INTO `#{searchTableName}`(#{keysSql}) VALUES (#{valsSql})"
      )
      return @_query(sql, values)
    )

  updateModelIndex: (model, indexData, isModelIndexed) =>
    searchTableName = "#{model.constructor.name}Search"
    @isModelIndexed(model, isModelIndexed)
    .then((isIndexed) =>
      if (not isIndexed)
        return @indexModel(model, indexData, isIndexed)

      indexFields = Object.keys(indexData)
      values = indexFields.map((key) => indexData[key]).concat([model.id])
      setSql = (
        indexFields
        .map((key) => "`#{key}` = ?")
        .join(', ')
      )
      sql = (
        "UPDATE `#{searchTableName}` SET #{setSql} WHERE `#{searchTableName}`.`content_id` = ?"
      )
      return @_query(sql, values)
    )

  unindexModel: (model) =>
    searchTableName = "#{model.constructor.name}Search"
    sql = (
      "DELETE FROM `#{searchTableName}` WHERE `#{searchTableName}`.`content_id` = ?"
    )
    return @_query(sql, [model.id])

  unindexModelsForAccount: (accountId, modelKlass) =>
    modelTable = modelKlass.name
    searchTableName = "#{modelTable}Search"
    sql = (
      "DELETE FROM `#{searchTableName}` WHERE `#{searchTableName}`.`content_id` IN
      (SELECT `id` FROM `#{modelTable}` WHERE `#{modelTable}`.`account_id` = ?)"
    )
    return @_query(sql, [accountId])

module.exports = new DatabaseStore()
module.exports.ChangeRecord = DatabaseChangeRecord
