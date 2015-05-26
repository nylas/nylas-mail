AtomWindow = require './atom-window'
BrowserWindow = require 'browser-window'
ApplicationMenu = require './application-menu'
NylasProtocolHandler = require './nylas-protocol-handler'
AutoUpdateManager = require './auto-update-manager'
WindowManager = require './window-manager'
Config = require '../config'
dialog = require 'dialog'

fs = require 'fs-plus'
Menu = require 'menu'
app = require 'app'
ipc = require 'ipc'
path = require 'path'
os = require 'os'
net = require 'net'
url = require 'url'
exec = require('child_process').exec
querystring = require 'querystring'
{EventEmitter} = require 'events'
_ = require 'underscore'

socketPath =
  if process.platform is 'win32'
    '\\\\.\\pipe\\edgehill-sock'
  else
    path.join(os.tmpdir(), 'edgehill.sock')

configDirPath = fs.absolute('~/.nylas')

# The application's singleton class.
#
# It's the entry point into the Atom application and maintains the global state
# of the application.
#
module.exports =
class Application
  _.extend @prototype, EventEmitter.prototype

  # Public: The entry point into the Nylas Mail application.
  @open: (options) ->
    createApplication = -> new Application(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or electron, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if (process.platform isnt 'win32' and not fs.existsSync socketPath) or options.test
      createApplication()
      return

    client = net.connect {path: socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.terminate()

    client.on 'error', createApplication

  windowManager: null
  applicationMenu: null
  nylasProtocolHandler: null
  resourcePath: null
  version: null

  exit: (status) -> app.exit(status)

  constructor: (options) ->
    {@resourcePath, @version, @devMode, @safeMode} = options

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    global.application = this

    @config = new Config({configDirPath, @resourcePath})
    @config.load()

    @databases = {}
    @windowManager = new WindowManager({@resourcePath, @config, @devMode, @safeMode})
    @autoUpdateManager = new AutoUpdateManager(@version)
    @applicationMenu = new ApplicationMenu(@version)
    @nylasProtocolHandler = new NylasProtocolHandler(@resourcePath, @safeMode)

    @listenForArgumentsFromNewProcess()
    @setupJavaScriptArguments()
    @handleEvents()

    @launchWithOptions(options)

  # Opens a new window based on the options provided.
  launchWithOptions: ({urlsToOpen, test, devMode, safeMode, specDirectory, specFilePattern, logFile}) ->
    if test
      @runSpecs({exitWhenDone: true, @resourcePath, specDirectory, specFilePattern, logFile})
    else
      @windowManager.ensurePrimaryWindowOnscreen()
      for urlToOpen in (urlsToOpen || [])
        @openUrl(urlToOpen)

  prepareDatabaseInterface: ->
    return @dblitePromise if @dblitePromise

    # configure a listener that watches for incoming queries over IPC,
    # executes them, and returns the responses to the remote renderer processes
    ipc.on 'database-query', (event, {databasePath, queryKey, query, values}) =>
      db = @databases[databasePath]
      done = (err, result) ->
        unless err
          runtime = db.lastQueryTime()
          if runtime > 250
            console.log("Query #{queryKey}: #{query} took #{runtime}msec")
        event.sender.send('database-result', {queryKey, err, result})

      return done(new Error("Database not prepared.")) unless db
      if query[0..5] is 'SELECT'
        db.query(query, values, null, done)
      else
        db.query(query, values, done)

    # return a promise that resolves after we've configured dblite for our platform
    return @dblitePromise = new Promise (resolve, reject) =>
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

  prepareDatabase: (databasePath, callback) ->
    @prepareDatabaseInterface().then (dblite) =>
      # Avoid opening a new connection to an existing database
      return callback() if @databases[databasePath]

      # Create a new database for the requested path
      db = dblite(databasePath)

      # By default, dblite stops all query execution when a query returns an error.
      # We want to propogate those errors out, but still allow queries to be made.
      db.ignoreErrors = true
      @databases[databasePath] = db

      # Tell the person who requested the database that they can begin making queries
      callback()

  teardownDatabase: (databasePath, callback) ->
    @databases[databasePath]?.close()
    delete @databases[databasePath]
    fs.unlink(databasePath, callback)

  teardownAllDatabases: ->
    for path, val of @databases
      @teardownDatabase(path)

  # Creates server to listen for additional atom application launches.
  #
  # You can run the atom command multiple times, but after the first launch
  # the other launches will just pass their information to this server and then
  # close immediately.
  listenForArgumentsFromNewProcess: ->
    @deleteSocketFile()
    server = net.createServer (connection) =>
      connection.on 'data', (data) =>
        @launchWithOptions(JSON.parse(data))

    server.listen socketPath
    server.on 'error', (error) -> console.error 'Application server failed', error

  deleteSocketFile: ->
    return if process.platform is 'win32'

    if fs.existsSync(socketPath)
      try
        fs.unlinkSync(socketPath)
      catch error
        # Ignore ENOENT errors in case the file was deleted between the exists
        # check and the call to unlink sync. This occurred occasionally on CI
        # which is why this check is here.
        throw error unless error.code is 'ENOENT'

  # Configures required javascript environment flags.
  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony'

  # Registers basic application commands, non-idempotent.
  # Note: If these events are triggered while an application window is open, the window
  # needs to manually bubble them up to the Application instance via IPC or they won't be
  # handled. This happens in workspace-element.coffee
  handleEvents: ->
    @on 'application:run-all-specs', ->
      @runSpecs
        exitWhenDone: false
        resourcePath: @resourcePath
        safeMode: @windowManager.focusedWindow()?.safeMode

    @on 'application:ship-logs', ->
      global.errorReporter.shipLogs("User triggered.")
      dialog.showMessageBox
        type: 'warning'
        buttons: ['OK']
        message: 'Your local Nylas Mail logs have been sent to LogStash.'
        title: 'Logs Shipped'

    @on 'application:run-package-specs', ->
      dialog.showOpenDialog {
        title: 'Choose a Package Directory'
        defaultPath: configDirPath,
        properties: ['openDirectory']
      }, (filenames) =>
        return if filenames.length is 0
        @runSpecs
          exitWhenDone: false
          resourcePath: @resourcePath
          specDirectory: filenames[0]

    @on 'application:run-benchmarks', ->
      @runBenchmarks()

    @on 'application:logout', =>
      @teardownAllDatabases()
      @config.set('nylas', null)
      @config.set('edgehill', null)

    @on 'application:quit', => app.quit()
    @on 'application:inspect', ({x,y, atomWindow}) ->
      atomWindow ?= @windowManager.focusedWindow()
      atomWindow?.browserWindow.inspectElement(x, y)

    @on 'application:send-feedback', => @windowManager.sendToMainWindow('send-feedback')
    @on 'application:show-main-window', => @windowManager.ensurePrimaryWindowOnscreen()
    @on 'application:check-for-update', => @autoUpdateManager.check()
    @on 'application:install-update', =>
      @quitting = true
      @windowManager.unregisterAllHotWindows()
      @autoUpdateManager.install()
    @on 'application:open-dev', =>
      @devMode = true
      @windowManager.closeMainWindow()
      @windowManager.devMode = true
      @windowManager.ensurePrimaryWindowOnscreen()

    if process.platform is 'darwin'
      @on 'application:about', -> Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
      @on 'application:bring-all-windows-to-front', -> Menu.sendActionToFirstResponder('arrangeInFront:')
      @on 'application:hide', -> Menu.sendActionToFirstResponder('hide:')
      @on 'application:hide-other-applications', -> Menu.sendActionToFirstResponder('hideOtherApplications:')
      @on 'application:minimize', -> Menu.sendActionToFirstResponder('performMiniaturize:')
      @on 'application:unhide-all-applications', -> Menu.sendActionToFirstResponder('unhideAllApplications:')
      @on 'application:zoom', -> Menu.sendActionToFirstResponder('zoom:')
    else
      @on 'application:minimize', -> @windowManager.focusedWindow()?.minimize()
      @on 'application:zoom', -> @windowManager.focusedWindow()?.maximize()

    app.on 'window-all-closed', =>
      @windowManager.windowClosedOrHidden()

    # Called before the app tries to close any windows.
    app.on 'before-quit', =>
      # Destroy hot windows so that they can't block the app from quitting.
      # (Electron will wait for them to finish loading before quitting.)
      @windowManager.unregisterAllHotWindows()
      # Allow the main window to be closed.
      @quitting = true

    # Called after the app has closed all windows.
    app.on 'will-quit', =>
      @teardownAllDatabases()
      @deleteSocketFile()

    app.on 'will-exit', =>
      @teardownAllDatabases()
      @deleteSocketFile()

    app.on 'open-file', (event, pathToOpen) ->
      event.preventDefault()

    app.on 'open-url', (event, urlToOpen) =>
      @openUrl(urlToOpen)
      event.preventDefault()

    ipc.on 'new-window', (event, options) =>
      @windowManager.newWindow(options)

    ipc.on 'register-hot-window', (event, options) =>
      @windowManager.registerHotWindow(options)

    app.on 'activate-with-no-open-windows', (event) =>
      @windowManager.ensurePrimaryWindowOnscreen()
      event.preventDefault()

    ipc.on 'update-application-menu', (event, template, keystrokesByCommand) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @applicationMenu.update(win, template, keystrokesByCommand)

    ipc.on 'command', (event, command) =>
      @emit(command)

    ipc.on 'window-command', (event, command, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      win.emit(command, args...)

    ipc.on 'call-window-method', (event, method, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      win[method](args...)

    ipc.on 'action-bridge-rebroadcast-to-all', (event, args...) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @windowManager.windows().forEach (atomWindow) ->
        return if atomWindow.browserWindow == win
        return unless atomWindow.browserWindow.webContents
        atomWindow.browserWindow.webContents.send('action-bridge-message', args...)

    ipc.on 'action-bridge-rebroadcast-to-main', (event, args...) =>
      mainWindow = @windowManager.mainWindow()
      return if not mainWindow
      return if BrowserWindow.fromWebContents(event.sender) is mainWindow
      mainWindow.browserWindow.webContents.send('action-bridge-message', args...)

    clipboard = null
    ipc.on 'write-text-to-selection-clipboard', (event, selectedText) ->
      clipboard ?= require 'clipboard'
      clipboard.writeText(selectedText, 'selection')

  # Public: Executes the given command.
  #
  # If it isn't handled globally, delegate to the currently focused window.
  #
  # command - The string representing the command.
  # args - The optional arguments to pass along.
  sendCommand: (command, args...) ->
    unless @emit(command, args...)
      focusedWindow = @windowManager.focusedWindow()
      if focusedWindow?
        focusedWindow.sendCommand(command, args...)
      else
        @sendCommandToFirstResponder(command)

  # Public: Executes the given command on the given window.
  #
  # command - The string representing the command.
  # atomWindow - The {AtomWindow} to send the command to.
  # args - The optional arguments to pass along.
  sendCommandToWindow: (command, atomWindow, args...) ->
    unless @emit(command, args...)
      if atomWindow?
        atomWindow.sendCommand(command, args...)
      else
        @sendCommandToFirstResponder(command)

  # Translates the command into OS X action and sends it to application's first
  # responder.
  sendCommandToFirstResponder: (command) ->
    return false unless process.platform is 'darwin'

    switch command
      when 'core:undo' then Menu.sendActionToFirstResponder('undo:')
      when 'core:redo' then Menu.sendActionToFirstResponder('redo:')
      when 'core:copy' then Menu.sendActionToFirstResponder('copy:')
      when 'core:cut' then Menu.sendActionToFirstResponder('cut:')
      when 'core:paste' then Menu.sendActionToFirstResponder('paste:')
      when 'core:select-all' then Menu.sendActionToFirstResponder('selectAll:')
      else return false
    true

  # Open a mailto:// url.
  #
  openUrl: (urlToOpen) ->
    {protocol} = url.parse(urlToOpen)
    if protocol is 'mailto:'
      @windowManager.sendToMainWindow('mailto', urlToOpen)
    else
      console.log "Ignoring unknown URL type: #{urlToOpen}"

  # Opens up a new {AtomWindow} to run specs within.
  #
  # options -
  #   :exitWhenDone - A Boolean that, if true, will close the window upon
  #                   completion.
  #   :resourcePath - The path to include specs from.
  #   :specPath - The directory to load specs from.
  #   :safeMode - A Boolean that, if true, won't run specs from ~/.atom/packages
  #               and ~/.atom/dev/packages, defaults to false.
  runSpecs: ({exitWhenDone, resourcePath, specDirectory, specFilePattern, logFile, safeMode}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'spec', 'spec-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'spec-bootstrap'))

    isSpec = true
    devMode = true
    safeMode ?= false
    new AtomWindow({bootstrapScript, resourcePath, exitWhenDone, isSpec, devMode, specDirectory, specFilePattern, logFile, safeMode})

  runBenchmarks: ({exitWhenDone, specDirectory}={}) ->
    try
      bootstrapScript = require.resolve(path.resolve(global.devResourcePath, 'benchmark', 'benchmark-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'benchmark', 'benchmark-bootstrap'))

    specDirectory ?= path.dirname(bootstrapScript)

    isSpec = true
    devMode = true
    new AtomWindow({bootstrapScript, @resourcePath, exitWhenDone, isSpec, specDirectory, devMode})
