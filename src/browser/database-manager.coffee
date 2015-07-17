_ = require 'underscore'
fs = require 'fs-plus'
path = require 'path'

{EventEmitter} = require 'events'

# The singleton Browser interface to the Nylas Mail database.
class DatabaseManager
  _.extend @prototype, EventEmitter.prototype

  constructor: ({@resourcePath}) ->
    @_databases = {}
    @_setupQueries = {}
    @_prepPromises = {}

  _query: (db, query, values, callback) ->
    if query[0..5] is 'SELECT'
      db.query(query, values, null, callback)
    else
      db.query(query, values, callback)

  # Public: Called by `DatabaseConnection` in each window to ensure the DB
  # is fully setup
  #
  # - `databasePath` The database we want to prepare
  # - `callback` A callback that's fired once the DB is setup. We can't
  #    return a promise because they don't work across the IPC bridge.
  #
  # Returns nothing
  prepare: (databasePath, databaseVersion, callback) =>
    if @_databases[databasePath]
      callback()
    else
      @_prepPromises[databasePath] ?= @_createNewDatabase(databasePath, databaseVersion)
      @_prepPromises[databasePath].then(callback).catch (err) ->
        console.error "DatabaseManager: Error in prepare:"
        console.error err

    return

  ## TODO: In the future migrations shouldn't come as DB creates from a
  # data objects in Utils. For now we'll pass them in here so we can
  # access them later. This also prevents us from adding an extra argument
  # to a bunch of functions in the chain.
  addSetupQueries: (databasePath, setupQueries=[]) =>
    @_setupQueries[databasePath] = setupQueries

  closeDatabaseConnection: (databasePath) ->
    @_databases[databasePath]?.close()
    delete @_databases[databasePath]
    delete @_prepPromises[databasePath]

  closeDatabaseConnections: ->
    for path, val of @_databases
      @closeDatabaseConnection(path)

  deleteDatabase: (db, path) =>
    new Promise (resolve, reject) =>
      delete @_databases[path]
      delete @_prepPromises[path]
      db.on 'close', ->
        if fs.existsSync(path)
          fs.unlinkSync(path)
        resolve()
      db.close()

  deleteAllDatabases: ->
    Promise.all(_.map(@_databases, @deleteDatabase)).catch (err) ->
      console.error(err)

  onIPCDatabaseQuery: (event, {databasePath, queryKey, query, values}) =>
    db = @_databases[databasePath]

    if not db
      result = null
      errJSONString = JSON.stringify(new Error("Database not prepared"))
      event.sender.send('database-result', {queryKey, errJSONString, result})
      return

    @_query db, query, values, (err, result) ->
      errJSONString = if err then JSON.stringify(err) else null
      event.sender.send('database-result', {queryKey, errJSONString, result})

  # Resolves when a new database has been created and the initial setup
  # migration has run successfuly.
  # Rejects with an Error if setup fails or if the database is too old.
  #
  _createNewDatabase: (databasePath, databaseVersion) ->
    @_getDBAdapter().then (dbAdapter) =>
      creating = not fs.existsSync(databasePath)

      # Create a new database for the requested path
      db = dbAdapter(databasePath)

      # By default, dblite stops all query execution when a query
      # returns an error.  We want to propogate those errors out, but
      # still allow queries to be made.
      db.ignoreErrors = true

      cleanupAfterError = (err) =>
        @deleteDatabase(db, databasePath).then =>
          @emit("setup-error", err)
          return Promise.reject(err)

      if creating
        versionCheck = @_setDatabaseVersion(db, databaseVersion)
      else
        versionCheck = @_checkDatabaseVersion(db, databaseVersion)

      versionCheck
      .catch(cleanupAfterError)
      .then =>
        @_runSetupQueries(db, @_setupQueries[databasePath])
        .catch(cleanupAfterError)
        .then =>
          @_databases[databasePath] = db
          return Promise.resolve()

  _setDatabaseVersion: (db, databaseVersion) ->
    new Promise (resolve, reject) =>
      db.query("PRAGMA user_version=#{databaseVersion}", [], null, resolve)

  _checkDatabaseVersion: (db, databaseVersion) ->
    new Promise (resolve, reject) ->
      db.query "PRAGMA user_version", [], null, (currentVersion) ->
        if currentVersion/1 isnt databaseVersion/1
          reject(new Error("Incorrect database schema version: #{currentVersion} not #{databaseVersion}"))
        else
          resolve()

  # Takes a set of queries to initialize the database with
  #
  # - `db` The database to initialize
  # - `setupQueries` A list of string queries to execute in order
  #
  # Returns a {Promise} that:
  #   - resolves when all setup queries are complete
  #   - rejects if any query had an error
  _runSetupQueries: (db, setupQueries=[]) ->
    Promise.all setupQueries.map (query) =>
      new Promise (resolve, reject) =>
        @_query db, query, [], (err, result) ->
          if err then reject(err) else resolve()

  _getDBAdapter: ->
    # return a promise that resolves after we've configured dblite for our platform
    return new Promise (resolve, reject) =>
      dblite = require('../../vendor/dblite-custom').withSQLite('3.8.6+')
      vendor = path.join(@resourcePath.replace('app.asar', 'app.asar.unpacked'), '/vendor')

      if process.platform is 'win32'
        dblite.bin = "#{vendor}/sqlite3-win32.exe"
        resolve(dblite)
      else if process.platform is 'linux'
        {exec} = require 'child_process'
        exec "uname -a", (err, stdout, stderr) ->
          arch = if stdout.toString().indexOf('x86_64') is -1 then "32" else "64"
          dblite.bin = "#{vendor}/sqlite3-linux-#{arch}"
          resolve(dblite)
      else if process.platform is 'darwin'
        dblite.bin = "#{vendor}/sqlite3-darwin"
        resolve(dblite)

module.exports = DatabaseManager
