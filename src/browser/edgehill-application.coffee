AtomWindow = require './atom-window'
ApplicationMenu = require './application-menu'
NylasProtocolHandler = require './nylas-protocol-handler'
AutoUpdateManager = require './auto-update-manager'
BrowserWindow = require 'browser-window'
Menu = require 'menu'
app = require 'app'
fs = require 'fs'
ipc = require 'ipc'
path = require 'path'
os = require 'os'
net = require 'net'
url = require 'url'
exec = require('child_process').exec
querystring = require 'querystring'
{EventEmitter} = require 'events'
_ = require 'underscore-plus'

socketPath =
  if process.platform is 'win32'
    '\\\\.\\pipe\\edgehill-sock'
  else
    path.join(os.tmpdir(), 'edgehill.sock')

# The application's singleton class.
#
# It's the entry point into the Atom application and maintains the global state
# of the application.
#
module.exports =
class AtomApplication
  _.extend @prototype, EventEmitter.prototype

  # Public: The entry point into the Atom application.
  @open: (options) ->
    createAtomApplication = -> new AtomApplication(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or atom-shell, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if (process.platform isnt 'win32' and not fs.existsSync socketPath) or options.test
      createAtomApplication()
      return

    client = net.connect {path: socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.terminate()

    client.on 'error', createAtomApplication

  windows: null
  mainWindow: null
  applicationMenu: null
  nylasProtocolHandler: null
  resourcePath: null
  version: null

  exit: (status) -> app.exit(status)

  constructor: (options) ->
    {@resourcePath, @version, @devMode, @safeMode} = options

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    global.atomApplication = this

    @pidsToOpenWindows = {}
    @mainWindow = null

    # A collection of active windows
    @windows = []

    @hotWindows = {}

    @databases = {}

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
      @showMainWindow({devMode, safeMode})
      @mainWindow.on "window:loaded", =>
        for urlToOpen in (urlsToOpen || [])
          @openUrl({urlToOpen})

  # Makes a new window appear of a certain `windowType`.
  #
  # In almost all cases, instead of booting up a new window from scratch,
  # we pass in new `windowProps` to a pre-loaded "hot window".
  #
  # Individual packages declare what windowTypes they support. We use this
  # to determine what packages to load in a given `windowType`. Inside a
  # package's `package.json` we expect to find an entry of the form:
  #
  #   "windowTypes": {
  #     "myCustomWindowType": true
  #     "someOtherWindowType": true
  #     "composer": true
  #   }
  #
  # Individual packages must also call `registerHotWindow` upon activation
  # to start the prepartion of `hotWindows` of various types.
  #
  # Once a hot window is registered, we'll have a hidden window with the
  # declared packages of that `windowType` pre-loaded.
  #
  # This means that when `newWindow` is called, instead of going through
  # the bootup process, it simply replaces key parameters and does a soft
  # reload via `windowPropsReceived`.
  #
  # Since the window is already loaded, there are only some options that
  # can be soft-reloaded. If you attempt to pass options that a soft
  # reload doesn't support, you'll be forced to load from a `coldStart`.
  #
  # Any options passed in here will be passed into the AtomWindow
  # constructor, which will eventually show up in the window's main
  # loadSettings, which is accessible via `atom.getLoadSettings()`
  #
  # REQUIRED options:
  #   - windowType: defaults "popout". This eventually ends up as
  #     atom.getWindowType()
  #
  # Valid options:
  #   - coldStart: true
  #   - windowProps: A good place to put any data components of the window
  #       need to initialize properly. NOTE: You can only put JSON
  #       serializable data. No functions!
  #   - title: The title of the page
  #
  # Other options that will trigger a
  #   - frame: defaults true. Whether or not the popup has a frame
  #   - forceNewWindow
  #
  # Other non required options:
  #   - All of the options of BrowserWindow
  #     https://github.com/atom/atom-shell/blob/master/docs/api/browser-window.md#new-browserwindowoptions
  newWindow: (options={}) ->
    supportedHotWindowKeys = [
      "title"
      "width"
      "height"
      "windowType"
      "windowProps"
    ]

    unsupported =  _.difference(Object.keys(options), supportedHotWindowKeys)
    if unsupported.length > 0
      console.log "WARNING! You are passing in options that can't be hotLoaded into a new window. Please either change the options or pass the `coldStart:true` option to suppress this warning. If it's just data for the window, please put them in the `windowProps` param."
      console.log unsupported

    # Make sure we registered the window
    if @hotWindows[options.windowType]?
      coldStart = options.coldStart
    else
      coldStart = true

    if coldStart
      @newColdWindow(options)
    else
      @newHotWindow(options)
    return

  # This sets up some windows in the background with the requested
  # packages already pre-loaded into it.
  #
  # REQUIRED options:
  #   - windowType: registers a new hot window of the given type. This is
  #   the key we use to find what packages to load and what kind of window
  #   to open
  #
  # Optional options:
  #   - replenishNum - (defaults 1) The number of hot windows to keep
  #   loaded at any given time. If your package is expected to use a large
  #   number of windows, it may be advisable to make this number more than
  #   1. Beware that each load is very resource intensive.
  #
  #   - windowPackages - A list of additional packages to load into a
  #   window in addition to those declared in various `package.json`s
  registerHotWindow: ({windowType, replenishNum, windowPackages}={}) ->
    if not windowType
      throw new Error("please provide a windowType when registering a hot window")

    @hotWindows ?= {}
    @hotWindows[windowType] ?= {}
    @hotWindows[windowType].replenishNum ?= (replenishNum ? 1)
    @hotWindows[windowType].loadedWindows ?= []
    @hotWindows[windowType].windowPackages ?= (windowPackages ? [])

    @_replenishHotWindows()

  defaultWindowOptions: ->
    devMode: @devMode
    safeMode: @safeMode
    windowType: 'popout'
    hideMenuBar: true
    resourcePath: @resourcePath
    bootstrapScript: require.resolve("../window-secondary-bootstrap")

  newColdWindow: (options={}) ->
    options = _.extend(@defaultWindowOptions(), options)
    w = new AtomWindow(options)
    w.showWhenLoaded()

  # Tries to create a new hot window. Since we're updating an existing
  # window instead of creatinga new one, there are limitations in the
  # options you can provide.
  newHotWindow: (options={}) ->
    hotWindowParams = @hotWindows[options.windowType]
    if not hotWindowParams?
      console.log "WARNING! The requested windowType '#{options.windowType}' has not been registered. Be sure to call `registerWindowType` first in your packages setup."
      @newColdWindow(options)
      return

    if hotWindowParams.loadedWindows.length is 0
      # No windows ready
      options.windowPackages = hotWindowParams.windowPackages
      @newColdWindow(options)
    else
      [win] = hotWindowParams.loadedWindows.splice(0,1)
      newLoadSettings = _.extend(win.loadSettings(), options)
      win.setLoadSettings(newLoadSettings)
      win.showWhenLoaded()

    @_replenishHotWindows()

  # There may be many windowTypes, each that request many windows of that
  # type (the `replenishNum`).
  #
  # Loading windows is very resource intensive, so we want to do them
  # sequentially.
  #
  # We also want to round-robin load across the breadth of window types
  # instead of loading all of the windows of a single type then moving on
  # to the next.
  #
  # We first need to cycle through the registered `hotWindows` and create
  # a breadth-first queue of window loads that we'll store in
  # `@_replenishQueue`.
  #
  # Next we need to start processing the `@_replenishQueue`
  __replenishHotWindows: =>
    @_replenishQueue = []
    queues = {}
    maxWin = 0
    for windowType, data of @hotWindows
      numOfType = data.replenishNum - data.loadedWindows.length
      maxWin = Math.max(numOfType, maxWin)
      if numOfType > 0
        options = @defaultWindowOptions()
        options.windowType = windowType
        options.windowPackages = data.windowPackages
        queues[windowType] ?= []
        queues[windowType].push(options) for [0...numOfType]

    for [0...maxWin]
      for windowType, optionsArray of queues
        if optionsArray.length > 0
          @_replenishQueue.push(optionsArray.shift())

    @_processReplenishQueue()

  _replenishHotWindows: _.debounce(AtomApplication::__replenishHotWindows, 100)

  _processReplenishQueue: ->
    return if @_processingQueue
    @_processingQueue = true
    if @_replenishQueue.length > 0
      options = @_replenishQueue.shift()
      console.log "---> Launching new '#{options.windowType}' window"
      newWindow = new AtomWindow(options)
      @hotWindows[options.windowType].loadedWindows.push(newWindow)
      newWindow.once 'window:loaded', =>
        @_processingQueue = false
        @_processReplenishQueue()
    else
      @_processingQueue = false

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
      vendor = @resourcePath + "/vendor"

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

  # Public: Removes the {AtomWindow} from the global window list.
  removeWindow: (window) ->
    @windows.splice @windows.indexOf(window), 1
    @applicationMenu?.enableWindowSpecificItems(false) if @windows.length == 0
    @windowClosedOrHidden()

  # Public: Adds the {AtomWindow} to the global window list.
  # IMPORTANT: AtomWindows add themselves - you don't need to manually add them
  addWindow: (window) ->
    @windows.push window
    @applicationMenu?.addWindow(window.browserWindow)
    window.once 'window:loaded', =>
      @autoUpdateManager.emitUpdateAvailableEvent(window)

    unless window.isSpec
      focusHandler = => @lastFocusedWindow = window
      closePreventedHandler = => @windowClosedOrHidden()
      window.on 'window:close-prevented', closePreventedHandler
      window.browserWindow.on 'focus', focusHandler
      window.browserWindow.once 'closed', =>
        @lastFocusedWindow = null if window is @lastFocusedWindow
        window.removeListener('window:close-prevented', closePreventedHandler)
        window.browserWindow.removeListener('focus', focusHandler)

  windowClosedOrHidden: ->
    if process.platform in ['win32', 'linux']
      visible = false
      visible ||= window.isVisible() for window in @windows
      if visible is false
        @quitting = true
        # Quitting the app from within a window event handler causes
        # an assertion error. Wait a moment.
        _.defer -> app.quit()

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
    @on 'application:run-all-specs', -> @runSpecs(exitWhenDone: false, resourcePath: global.devResourcePath, safeMode: @focusedWindow()?.safeMode)
    @on 'application:run-benchmarks', -> @runBenchmarks()
    @on 'application:quit', =>
      @quitting = true
      app.quit()
    @on 'application:inspect', ({x,y, atomWindow}) ->
      atomWindow ?= @focusedWindow()
      atomWindow?.browserWindow.inspectElement(x, y)

    @on 'application:open-documentation', -> require('shell').openExternal('https://atom.io/docs/latest/?app')
    @on 'application:open-discussions', -> require('shell').openExternal('https://discuss.atom.io')
    @on 'application:open-roadmap', -> require('shell').openExternal('https://atom.io/roadmap?app')
    @on 'application:open-faq', -> require('shell').openExternal('https://atom.io/faq')
    @on 'application:open-terms-of-use', -> require('shell').openExternal('https://atom.io/terms')
    @on 'application:report-issue', => @_reportIssue()
    @on 'application:search-issues', -> require('shell').openExternal('https://github.com/issues?q=+is%3Aissue+user%3Aatom')

    @on 'application:show-main-window', => @showMainWindow()

    @on 'application:check-for-update', => @autoUpdateManager.check()
    @on 'application:install-update', =>
      @quitting = true
      @autoUpdateManager.install()

    if process.platform is 'darwin'
      @on 'application:about', -> Menu.sendActionToFirstResponder('orderFrontStandardAboutPanel:')
      @on 'application:bring-all-windows-to-front', -> Menu.sendActionToFirstResponder('arrangeInFront:')
      @on 'application:hide', -> Menu.sendActionToFirstResponder('hide:')
      @on 'application:hide-other-applications', -> Menu.sendActionToFirstResponder('hideOtherApplications:')
      @on 'application:minimize', -> Menu.sendActionToFirstResponder('performMiniaturize:')
      @on 'application:unhide-all-applications', -> Menu.sendActionToFirstResponder('unhideAllApplications:')
      @on 'application:zoom', -> Menu.sendActionToFirstResponder('zoom:')
    else
      @on 'application:minimize', -> @focusedWindow()?.minimize()
      @on 'application:zoom', -> @focusedWindow()?.maximize()

    app.on 'window-all-closed', ->
      @windowClosedOrHidden()

    app.on 'will-quit', =>
      @deleteSocketFile()

    app.on 'will-exit', =>
      @deleteSocketFile()

    app.on 'open-file', (event, pathToOpen) ->
      event.preventDefault()

    app.on 'open-url', (event, urlToOpen) =>
      @openUrl({urlToOpen})
      event.preventDefault()

    ipc.on 'new-window', (event, options) => @newWindow(options)

    ipc.on 'register-hot-window', (event, options) => @registerHotWindow(options)

    app.on 'activate-with-no-open-windows', (event) =>
      event.preventDefault()
      @showMainWindow()

    ipc.on 'onboarding-complete', (event, options) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @windows.forEach (atomWindow) ->
        return if atomWindow.browserWindow == win
        return unless atomWindow.browserWindow.webContents
        atomWindow.browserWindow.webContents.send('onboarding-complete')

    ipc.on 'update-application-menu', (event, template, keystrokesByCommand) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @applicationMenu.update(win, template, keystrokesByCommand)

    ipc.on 'run-package-specs', (event, specDirectory) =>
      @runSpecs({resourcePath: global.devResourcePath, specDirectory: specDirectory, exitWhenDone: false})

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
      @windows.forEach (atomWindow) ->
        return if atomWindow.browserWindow == win
        return unless atomWindow.browserWindow.webContents
        atomWindow.browserWindow.webContents.send('action-bridge-message', args...)

    ipc.on 'action-bridge-rebroadcast-to-main', (event, args...) =>
      return unless @mainWindow
      return if BrowserWindow.fromWebContents(event.sender) is @mainWindow
      @mainWindow.browserWindow.webContents.send('action-bridge-message', args...)

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
      focusedWindow = @focusedWindow()
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

  # Returns the {AtomWindow} for the given ipc event.
  windowForEvent: ({sender}) ->
    window = BrowserWindow.fromWebContents(sender)
    _.find @windows, ({browserWindow}) -> window is browserWindow

  # Public: Returns the currently focused {AtomWindow} or undefined if none.
  focusedWindow: ->
    _.find @windows, (atomWindow) -> atomWindow.isFocused()

  # Public: Opens or unhides the main application window
  #
  # options -
  #   :devMode - Boolean to control the opened window's dev mode.
  #   :safeMode - Boolean to control the opened window's safe mode.
  showMainWindow: ({devMode, safeMode}={}) ->
    if @mainWindow
      if @mainWindow.isMinimized()
        @mainWindow.restore()
      else if !@mainWindow.isVisible()
        @mainWindow.show()
      @mainWindow.focus()
    else
      if devMode
        try
          bootstrapScript = require.resolve(path.join(global.devResourcePath, 'src', 'window-bootstrap'))
          resourcePath = global.devResourcePath

      bootstrapScript ?= require.resolve('../window-bootstrap')
      resourcePath ?= @resourcePath
      neverClose = true
      frame = true
      mainWindow = true

      if process.platform is 'darwin'
        frame = false

      @mainWindow = new AtomWindow({bootstrapScript, resourcePath, devMode, safeMode, neverClose, frame, mainWindow})

  # Open an atom:// or mailto:// url.
  #
  # options -
  #   :urlToOpen - The atom:// or mailto:// url to open.
  #   :devMode - Boolean to control the opened window's dev mode.
  #   :safeMode - Boolean to control the opened window's safe mode.
  openUrl: ({urlToOpen, devMode, safeMode}) ->
    parts = url.parse(urlToOpen)

    # Attempt to parse the mailto link into Message object JSON
    # and then open a composer window
    if parts.protocol is 'mailto:'
      @mainWindow.browserWindow.webContents.send('mailto', urlToOpen)

    # The host of the URL being opened is assumed to be the package name
    # responsible for opening the URL.  A new window will be created with
    # that package's `urlMain` as the bootstrap script.
    else if parts.protocol is 'atom:'
      unless @packages?
        PackageManager = require '../package-manager'
        fs = require 'fs-plus'
        @packages = new PackageManager
          configDirPath: fs.absolute('~/.atom')
          devMode: devMode
          resourcePath: @resourcePath

      packageName = url.parse(urlToOpen).host
      pack = _.find @packages.getAvailablePackageMetadata(), ({name}) -> name is packageName
      if pack?
        if pack.urlMain
          packagePath = @packages.resolvePackagePath(packageName)
          bootstrapScript = path.resolve(packagePath, pack.urlMain)
          windowDimensions = @focusedWindow()?.getDimensions()
          new AtomWindow({bootstrapScript, @resourcePath, devMode, safeMode, urlToOpen, windowDimensions})
        else
          console.log "Package '#{pack.name}' does not have a url main: #{urlToOpen}"
      else
        console.log "Opening unknown url: #{urlToOpen}"

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

  _reportIssue: ->
    return unless @mainWindow
    @mainWindow.browserWindow.webContents.send('report-issue')
