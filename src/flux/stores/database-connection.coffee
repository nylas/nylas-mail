_ = require 'underscore'
ipc = require 'ipc'
remote = require 'remote'

PriorityUICoordinator = require '../../priority-ui-coordinator'

{AttributeCollection, AttributeJoinedData} = require '../attributes'

{modelClassMap,
 tableNameForJoin} = require '../models/utils'

DEBUG_TO_LOG = false

# The DatabaseConnection dispatches queries to the Browser process via IPC and listens
# for results. It maintains a hash of `_queryRecords` representing queries that are
# currently running and fires promise callbacks when complete.
#
class DatabaseConnection
  constructor: (@_databasePath, @_databaseVersion) ->
    @_queryId = 0
    @_windowId = remote.getCurrentWindow().id
    @_isConnected = false
    @_queryRecords = {}
    @_pendingQueries = []

    ipc.on 'database-result', @_onDatabaseResult

    return @

  # This grabs a reference to database from the browser backend
  connect: ->
    @_isConnected = false
    databaseManager = remote.getGlobal('application').databaseManager

    # TODO Make this a nicer migration-based system
    # It's important these queries always get added. Don't worry, they'll
    # only run if the DB doesn't exist yet, and even if they do run they
    # all have `IF NOT EXISTS` clauses in them.
    databaseManager.addSetupQueries(@_databasePath, @_setupQueries())

    databaseManager.prepare @_databasePath, @_databaseVersion, =>
      @_isConnected = true
      @_flushPendingQueries()

  # Executes a query via IPC and returns a promise that resolves or
  # rejects when the query is complete.
  #
  # We don't know if the query is complete until the `database-result` ipc
  # command returns, so we need to cache the Promise's resolve and reject
  # handlers
  query: (query, values=[], options={}) =>
    if not query
      throw new Error("DatabaseConnection: You need to provide a query string.")

    return new Promise (resolve, reject) =>
      @_queryId += 1
      queryKey = "#{@_windowId}-#{@_queryId}"

      @_queryRecords[queryKey] = {
        query: query
        start: Date.now()
        values: values
        reject: reject
        resolve: resolve
        options: options
      }

      if @isConnected()
        databasePath = @_databasePath
        ipc.send('database-query', {databasePath, queryKey, query, values})
      else
        @_pendingQueries.push({queryKey, query, values})

  isConnected: -> @_isConnected

  _flushPendingQueries: =>
    qs = _.clone(@_pendingQueries)
    @_pendingQueries = []
    for queryArgs in qs
      {queryKey, query, values} = queryArgs
      databasePath = @_databasePath
      ipc.send('database-query', {databasePath, queryKey, query, values})

  _onDatabaseResult: ({queryKey, errJSONString, result}) =>
    record = @_queryRecords[queryKey]
    return unless record

    {query, start, values, reject, resolve, options} = record

    if errJSONString
      # Note: Error objects turn into JSON when went through the IPC bridge.
      # In case downstream code checks instanceof Error, convert back into
      # a real error objet.
      errJSON = JSON.parse(errJSONString)
      err = new Error()
      for key, val of errJSON
        err[key] = val

    @_logQuery(query, start, result)

    if options.evaluateImmediately
      uiBusyPromise = Promise.resolve()
    else
      uiBusyPromise = PriorityUICoordinator.settle

    uiBusyPromise.then =>
      delete @_queryRecords[queryKey]
      if err
        @_logQueryError(err.message, query, values)
        reject(err)
      else
        resolve(result)

  _logQuery: (query, start, result) ->
    duration = Date.now() - start
    metadata =
      duration: duration
      resultLength: result?.length

    console.debug(DEBUG_TO_LOG, "DatabaseStore: (#{duration}) #{query}", metadata)
    if duration > 300
      atom.errorReporter.shipLogs("Poor Query Performance")

  _logQueryError: (message, query, values) ->
    console.error("DatabaseStore: Query #{query}, #{JSON.stringify(values)} failed #{message ? ""}")


  ## TODO: Make these a nicer migration-based system
  _setupQueries: ->
    queries = []
    queries.push "PRAGMA journal_mode=WAL;"
    for key, klass of modelClassMap()
      continue unless klass.attributes
      queries = queries.concat @_setupQueriesForTable(klass)
    return queries

  _setupQueriesForTable: (klass) =>
    attributes = _.values(klass.attributes)
    queries = []

    # Identify attributes of this class that can be matched against. These
    # attributes need their own columns in the table
    columnAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr.columnSQL && attr.jsonKey != 'id'

    columns = ['id TEXT PRIMARY KEY', 'data BLOB']
    columnAttributes.forEach (attr) ->
      columns.push(attr.columnSQL())

    columnsSQL = columns.join(',')
    queries.unshift("CREATE TABLE IF NOT EXISTS `#{klass.name}` (#{columnsSQL})")
    queries.push("CREATE UNIQUE INDEX IF NOT EXISTS `#{klass.name}_id` ON `#{klass.name}` (`id`)")

    # Identify collection attributes that can be matched against. These require
    # JOIN tables. (Right now the only one of these is Thread.folders or
    # Thread.labels)
    collectionAttributes = _.filter attributes, (attr) ->
      attr.queryable && attr instanceof AttributeCollection
    collectionAttributes.forEach (attribute) ->
      joinTable = tableNameForJoin(klass, attribute.itemClass)
      joinIndexName = "#{joinTable.replace('-', '_')}_id_val"
      queries.push("CREATE TABLE IF NOT EXISTS `#{joinTable}` (id TEXT KEY, `value` TEXT)")
      queries.push("CREATE UNIQUE INDEX IF NOT EXISTS `#{joinIndexName}` ON `#{joinTable}` (`id`,`value`)")

    joinedDataAttributes = _.filter attributes, (attr) ->
      attr instanceof AttributeJoinedData
    joinedDataAttributes.forEach (attribute) ->
      queries.push("CREATE TABLE IF NOT EXISTS `#{attribute.modelTable}` (id TEXT PRIMARY KEY, `value` TEXT)")

    if klass.additionalSQLiteConfig?.setup?
      queries = queries.concat(klass.additionalSQLiteConfig.setup())
    queries

module.exports = DatabaseConnection
