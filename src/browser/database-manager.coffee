_ = require 'underscore'
fs = require 'fs-plus'
path = require 'path'

{EventEmitter} = require 'events'

# The singleton Browser interface to the Nylas Mail database.
class DatabaseManager
  _.extend @prototype, EventEmitter.prototype

  constructor: ({@resourcePath}) ->
    @_databases = {}
    @_prepPromises = {}

  _query: (db, query, values) ->
    return new Promise (resolve, reject) ->
      onQueryComplete = (err, result) ->
        if err
          reject(err)
        else
          runtime = db.lastQueryTime()
          if runtime > 250
            console.log("Query #{queryKey}: #{query} took #{runtime}msec")
          resolve(result)

      if query[0..5] is 'SELECT'
        db.query(query, values, null, onQueryComplete)
      else
        db.query(query, values, onQueryComplete)

  # Public: Called by `DatabaseConnection` in each window to ensure the DB
  # is fully setup
  #
  # - `databasePath` The database we want to prepare
  # - `callback` A callback that's fired once the DB is setup. We can't
  #    return a promise because they don't work across the IPC bridge.
  #
  # Returns nothing
  prepare: (databasePath, callback) =>
    if @_databases[databasePath]
      callback()
    else
      @_prepPromises[databasePath] ?= @_createNewDatabase(databasePath).then (db) =>
        @_databases[databasePath] = db
        return Promise.resolve()

      @_prepPromises[databasePath].then(callback).catch (err) ->
        console.error "Error preparing the database"
        console.error err

    return

  ## TODO: In the future migrations shouldn't come as DB creates from a
  # data objects in Utils. For now we'll pass them in here so we can
  # access them later. This also prevents us from adding an extra argument
  # to a bunch of functions in the chain.
  addSetupQueries: (databasePath, setupQueries=[]) =>
    @_setupQueries ?= {}
    @_setupQueries[databasePath] = setupQueries

  _closeDatabaseConnection: (databasePath) ->
    @_databases[databasePath]?.close()
    delete @_databases[databasePath]

  closeDatabaseConnections: ->
    for path, val of @_databases
      @_closeDatabaseConnection(path)

  onIPCDatabaseQuery: (event, {databasePath, queryKey, query, values}) =>
    db = @_databases[databasePath]

    if not db
      err = new Error("Database not prepared"); result = null
      event.sender.send('database-result', {queryKey, err, result})
      return

    @_query(db, query, values).then (result) ->
      err = null
      event.sender.send('database-result', {queryKey, err, result})
    .catch (err) ->
      result = null
      event.sender.send('database-result', {queryKey, err, result})

  # Resolves when a new database has been created and the initial setup
  # migration has run successfuly.
  _createNewDatabase: (databasePath) ->
    @_getDBAdapter().then (dbAdapter) =>
      # Create a new database for the requested path
      db = dbAdapter(databasePath)

      # By default, dblite stops all query execution when a query
      # returns an error.  We want to propogate those errors out, but
      # still allow queries to be made.
      db.ignoreErrors = true

      setupQueries = @_setupQueries?[databasePath] ? []

      # Resolves when the DB has been initalized
      return @_runSetupQueries(db, setupQueries)

  # Takes a set of queries to initialize the database with
  #
  # - `db` The database to initialize
  # - `setupQueries` A list of string queries to execute in order
  #
  # Returns a {Promise} that:
  #   - resolves when all setup queries are complete
  #   - rejects if any query had an error
  _runSetupQueries: (db, setupQueries=[]) ->
    setupPromise = Promise.all setupQueries.map (query) =>
      @_query(db, query, [])

    setupPromise.then ->
      return Promise.resolve(db)
    .catch (err) ->
      @emit "setup-error", err
      @_deleteAllDatabases()
      console.error "There was an error setting up the database #{err?.message}"
      return Promise.reject(err)

  _getDBAdapter: ->
    # return a promise that resolves after we've configured dblite for our platform
    return new Promise (resolve, reject) =>
      dblite = require('../../vendor/dblite-custom').withSQLite('3.8.6+')
      vendor = path.join(@resourcePath.replace('app.asar', 'app.asar.unpacked'), '/vendor')

      if process.platform is 'win32'
        dblite.bin = "#{vendor}/sqlite3-win32.exe"
        resolve(dblite)
      else if process.platform is 'linux'
        exec "uname -a", (err, stdout, stderr) ->
          arch = if stdout.toString().indexOf('x86_64') is -1 then "32" else "64"
          dblite.bin = "#{vendor}/sqlite3-linux-#{arch}"
          resolve(dblite)
      else if process.platform is 'darwin'
        dblite.bin = "#{vendor}/sqlite3-darwin"
        resolve(dblite)

  _deleteAllDatabases: ->
    for path, val of @_databases
      @closeDatabaseConnection(path)
      fs.unlinkSync(path)

module.exports = DatabaseManager
