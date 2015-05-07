crypto = require 'crypto'
ipc = require 'ipc'
os = require 'os'
path = require 'path'
remote = require 'remote'
shell = require 'shell'

_ = require 'underscore-plus'
{deprecate} = require 'grim'
{Emitter} = require 'event-kit'
{Model} = require 'theorist'
fs = require 'fs-plus'
{convertStackTrace, convertLine} = require 'coffeestack'

WindowEventHandler = require './window-event-handler'
StylesElement = require './styles-element'

# Essential: Atom global for dealing with packages, themes, menus, and the window.
#
# An instance of this class is always available as the `atom` global.
module.exports =
class Atom extends Model
  @version: 1  # Increment this when the serialization format changes

  # Load or create the application environment
  # Returns an Atom instance, fully initialized
  @loadOrCreate: ->
    startTime = Date.now()

    savedState = @_loadSavedState()
    if savedState and savedState?.version is @version
      app = new this(savedState)
    else
      app = new this({@version})

    app.deserializeTimings.app = Date.now() -  startTime
    return app

  # Loads and returns the serialized state corresponding to this window
  # if it exists; otherwise returns undefined.
  @_loadSavedState: ->
    statePath = @getStatePath()

    if fs.existsSync(statePath)
      try
        stateString = fs.readFileSync(statePath, 'utf8')
      catch error
        console.warn "Error reading window state: #{statePath}", error.stack, error
    else
      stateString = @getLoadSettings().windowState

    try
      JSON.parse(stateString) if stateString?
    catch error
      console.warn "Error parsing window state: #{statePath} #{error.stack}", error

  # Returns the path where the state for the current window will be
  # located if it exists.
  @getStatePath: ->
    if @getLoadSettings().isSpec
      filename = 'spec'
    else
      {initialPath} = @getLoadSettings()
      if initialPath
        sha1 = crypto.createHash('sha1').update(initialPath).digest('hex')
        filename = "application-#{sha1}"

    if filename
      path.join(@getStorageDirPath(), filename)
    else
      null

  # Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to ~/.inbox
  @getConfigDirPath: ->
    @configDirPath ?= fs.absolute('~/.inbox')

  # Get the path to Atom's storage directory.
  #
  # Returns the absolute path to ~/.inbox/storage
  @getStorageDirPath: ->
    @storageDirPath ?= path.join(@getConfigDirPath(), 'storage')

  # Returns the load settings hash associated with the current window.
  @getLoadSettings: ->
    @loadSettings ?= JSON.parse(decodeURIComponent(location.search.substr(14)))

    cloned = _.deepClone(@loadSettings)
    # The loadSettings.windowState could be large, request it only when needed.
    cloned.__defineGetter__ 'windowState', =>
      @getCurrentWindow().loadSettings.windowState
    cloned.__defineSetter__ 'windowState', (value) =>
      @getCurrentWindow().loadSettings.windowState = value
    cloned

  @getCurrentWindow: ->
    remote.getCurrentWindow()

  workspaceViewParentSelector: 'body'
  lastUncaughtError: null

  ###
  Section: Properties
  ###

  # Public: A {CommandRegistry} instance
  commands: null

  # Public: A {Config} instance
  config: null

  # Public: A {Clipboard} instance
  clipboard: null

  # Public: A {MenuManager} instance
  menu: null

  # Public: A {KeymapManager} instance
  keymaps: null

  # Experimental: A {NotificationManager} instance
  notifications: null

  # Public: A {PackageManager} instance
  packages: null

  # Public: A {ThemeManager} instance
  themes: null

  # Public: A {StyleManager} instance
  styles: null

  # Public: A {DeserializerManager} instance
  deserializers: null

  ###
  Section: Construction and Destruction
  ###

  # Call .loadOrCreate instead
  constructor: (@savedState={}) ->
    {@version} = @savedState
    @emitter = new Emitter
    DeserializerManager = require './deserializer-manager'
    @deserializers = new DeserializerManager()
    @deserializeTimings = {}

  # Sets up the basic services that should be available in all modes
  # (both spec and application).
  #
  # Call after this instance has been assigned to the `atom` global.
  initialize: ->
    # Disable deprecations unless in dev mode or spec mode so that regular
    # editor performance isn't impacted by generating stack traces for
    # deprecated calls.
    unless @inDevMode() or @inSpecMode()
      require('grim').deprecate = ->

    @setupErrorHandling()

    @unsubscribe()
    @setBodyPlatformClass()

    @loadTime = null

    Config = require './config'
    KeymapManager = require './keymap-extensions'
    CommandRegistry = require './command-registry'
    NotificationManager = require './notification-manager'
    PackageManager = require './package-manager'
    Clipboard = require './clipboard'
    ThemeManager = require './theme-manager'
    StyleManager = require './style-manager'
    ActionBridge = require './flux/action-bridge'
    InboxAPI = require './flux/inbox-api'
    MenuManager = require './menu-manager'
    {devMode, safeMode, resourcePath} = @getLoadSettings()
    configDirPath = @getConfigDirPath()

    # Add 'exports' to module search path.
    exportsPath = path.join(resourcePath, 'exports')
    require('module').globalPaths.push(exportsPath)

    # Still set NODE_PATH since tasks may need it.
    process.env.NODE_PATH = exportsPath

    # Make react.js faster
    process.env.NODE_ENV ?= 'production' unless devMode

    # Set Atom's home so packages don't have to guess it
    process.env.ATOM_HOME = configDirPath

    # Setup config and load it immediately so it's available to our singletons
    @config = new Config({configDirPath, resourcePath})

    @keymaps = new KeymapManager({configDirPath, resourcePath})
    @keymaps.subscribeToFileReadFailure()
    @keymaps.onDidMatchBinding (event) ->
      # If the user fired a command with the application: prefix bound to the body, re-fire it
      # up into the browser process. This prevents us from needing this crap, which has to be
      # updated every time a new application: command is added:
      # https://github.com/atom/atom/blob/master/src/workspace-element.coffee#L119
      if event.binding.command.indexOf('application:') is 0 and event.binding.selector is "body"
        ipc.send('command', event.binding.command)

    @notifications = new NotificationManager
    @commands = new CommandRegistry
    @packages = new PackageManager({devMode, configDirPath, resourcePath, safeMode})
    @styles = new StyleManager
    @actionBridge = new ActionBridge(ipc)
    document.head.appendChild(new StylesElement)
    @themes = new ThemeManager({packageManager: @packages, configDirPath, resourcePath, safeMode})
    @menu = new MenuManager({resourcePath})
    @clipboard = new Clipboard()

    # Edgehill-specific
    @inbox = new InboxAPI()

    # initialize spell checking
    require('web-frame').setSpellCheckProvider("en-US", false, {
      spellCheck: (text) ->
        !(require('spellchecker').isMisspelled(text))
    })

    @subscribe @packages.onDidActivateInitialPackages => @watchThemes()
    @windowEventHandler = new WindowEventHandler

    window.onbeforeunload = => @onBeforeUnload()

  # Start our error reporting to the backend and attach error handlers
  # to the window and the Bluebird Promise library, converting things
  # back through the sourcemap as necessary.
  setupErrorHandling: ->
    ErrorReporter = require './error-reporter'
    @errorReporter = new ErrorReporter()
    sourceMapCache = {}

    window.onerror = =>
      @lastUncaughtError = Array::slice.call(arguments)
      [message, url, line, column, originalError] = @lastUncaughtError

      # Convert the javascript error back into a Coffeescript error
      convertedLine = convertLine(url, line, column, sourceMapCache)
      {line, column} = convertedLine if convertedLine?
      originalError.stack = convertStackTrace(originalError.stack, sourceMapCache) if originalError

      eventObject = {message, url, line, column, originalError}

      openDevTools = true
      eventObject.preventDefault = -> openDevTools = false

      # Announce that we will display the error. Recipients can call preventDefault
      # to prevent the developer tools from being shown
      @emitter.emit('will-throw-error', eventObject)

      if openDevTools
        @openDevTools()
        @executeJavaScriptInDevTools('InspectorFrontendAPI.showConsole()')

      # Announce that the error was uncaught
      @emit('uncaught-error', arguments...)
      @emitter.emit('did-throw-error', eventObject)

    # Since Bluebird is the promise library, we can properly report
    # unhandled errors from business logic inside promises.
    Promise.longStackTraces() unless @inSpecMode()
    Promise.onPossiblyUnhandledRejection (error) =>
      # In many cases, a promise will return a legitimate error which the receiver
      # doesn't care to handle. The ones we want to surface are core javascript errors:
      # Syntax problems, type errors, etc. If we didn't catch them here, these issues
      # (usually inside then() blocks) would be hard to track down.
      return unless (error instanceof TypeError or
                     error instanceof SyntaxError or
                     error instanceof RangeError or
                     error instanceof ReferenceError)

      error.stack = convertStackTrace(error.stack, sourceMapCache)
      eventObject = {message: error.message, originalError: error}

      if @inSpecMode()
        console.warn(error.stack)
      else
        console.warn(error)
        console.warn(error.stack)

      @emitter.emit('will-throw-error', eventObject)
      @emit('uncaught-error', error.message, null, null, null, error)
      @emitter.emit('did-throw-error', eventObject)

  ###
  Section: Event Subscription
  ###

  # Extended: Invoke the given callback whenever {::beep} is called.
  #
  # * `callback` {Function} to be called whenever {::beep} is called.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidBeep: (callback) ->
    @emitter.on 'did-beep', callback

  # Extended: Invoke the given callback when there is an unhandled error, but
  # before the devtools pop open
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  #   * `event` {Object}
  #     * `originalError` {Object} the original error object
  #     * `message` {String} the original error object
  #     * `url` {String} Url to the file where the error originated.
  #     * `line` {Number}
  #     * `column` {Number}
  #     * `preventDefault` {Function} call this to avoid popping up the dev tools.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillThrowError: (callback) ->
    @emitter.on 'will-throw-error', callback

  # Extended: Invoke the given callback whenever there is an unhandled error.
  #
  # * `callback` {Function} to be called whenever there is an unhandled error
  #   * `event` {Object}
  #     * `originalError` {Object} the original error object
  #     * `message` {String} the original error object
  #     * `url` {String} Url to the file where the error originated.
  #     * `line` {Number}
  #     * `column` {Number}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidThrowError: (callback) ->
    @emitter.on 'did-throw-error', callback

  ###
  Section: Atom Details
  ###
  isMainWindow: ->
    !!@getLoadSettings().mainWindow

  getWindowType: ->
    @getLoadSettings().windowType

  # Public: Is the current window in development mode?
  inDevMode: ->
    @getLoadSettings().devMode

  # Public: Is the current window in safe mode?
  inSafeMode: ->
    @getLoadSettings().safeMode

  # Public: Is the current window running specs?
  inSpecMode: ->
    @getLoadSettings().isSpec

  # Public: Get the version of the Atom application.
  #
  # Returns the version text {String}.
  getVersion: ->
    @appVersion ?= @getLoadSettings().appVersion

  # Public: Determine whether the current version is an official release.
  isReleasedVersion: ->
    not /\w{7}/.test(@getVersion()) # Check if the release is a 7-character SHA prefix

  isLoggedIn: ->
    atom.config.get('inbox.token')

  # Public: Get the directory path to Atom's configuration area.
  #
  # Returns the absolute path to `~/.atom`.
  getConfigDirPath: ->
    @constructor.getConfigDirPath()

  # Public: Get the time taken to completely load the current window.
  #
  # This time include things like loading and activating packages, creating
  # DOM elements for the editor, and reading the config.
  #
  # Returns the {Number} of milliseconds taken to load the window or null
  # if the window hasn't finished loading yet.
  getWindowLoadTime: ->
    @loadTime

  # Public: Get the load settings for the current window.
  #
  # Returns an {Object} containing all the load setting key/value pairs.
  getLoadSettings: ->
    @constructor.getLoadSettings()

  ###
  Section: Managing The Atom Window
  ###

  # Essential: Close the current window.
  close: ->
    @getCurrentWindow().close()

  # Essential: Get the size of current window.
  #
  # Returns an {Object} in the format `{width: 1000, height: 700}`
  getSize: ->
    [width, height] = @getCurrentWindow().getSize()
    {width, height}

  # Essential: Set the size of current window.
  #
  # * `width` The {Number} of pixels.
  # * `height` The {Number} of pixels.
  setSize: (width, height) ->
    @getCurrentWindow().setSize(width, height)

  # Essential: Get the position of current window.
  #
  # Returns an {Object} in the format `{x: 10, y: 20}`
  getPosition: ->
    [x, y] = @getCurrentWindow().getPosition()
    {x, y}

  # Essential: Set the position of current window.
  #
  # * `x` The {Number} of pixels.
  # * `y` The {Number} of pixels.
  setPosition: (x, y) ->
    ipc.send('call-window-method', 'setPosition', x, y)

  # Extended: Get the current window
  getCurrentWindow: ->
    @constructor.getCurrentWindow()

  # Extended: Move current window to the center of the screen.
  center: ->
    ipc.send('call-window-method', 'center')

  # Extended: Focus the current window.
  focus: ->
    ipc.send('call-window-method', 'focus')
    window.focus()

  # Extended: Show the current window.
  show: ->
    ipc.send('call-window-method', 'show')

  isVisible: ->
    @getCurrentWindow().isVisible()

  # Extended: Hide the current window.
  hide: ->
    ipc.send('call-window-method', 'hide')

  # Extended: Reload the current window.
  reload: ->
    ipc.send('call-window-method', 'restart')

  # Calls the `windowPropsReceived` method of all packages that are
  # currently loaded
  loadSettingsChanged: (loadSettings) =>
    @loadSettings = loadSettings
    @constructor.loadSettings = loadSettings
    {width, height, windowProps} = loadSettings

    @packages.windowPropsReceived(windowProps ? {})

    if width and height
      @setWindowDimensions({width, height})

  # Extended: Returns a {Boolean} true when the current window is maximized.
  isMaximixed: ->
    @getCurrentWindow().isMaximized()

  maximize: ->
    ipc.send('call-window-method', 'maximize')

  minimize: ->
    ipc.send('call-window-method', 'minimize')

  # Extended: Is the current window in full screen mode?
  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  # Extended: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    ipc.send('call-window-method', 'setFullScreen', fullScreen)
    if fullScreen then document.body.classList.add("fullscreen") else document.body.classList.remove("fullscreen")

  # Extended: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  # Schedule the window to be shown and focused on the next tick.
  #
  # This is done in a next tick to prevent a white flicker from occurring
  # if called synchronously.
  displayWindow: ({maximize}={}) ->
    setImmediate =>
      @show()
      @focus()
      @maximize() if maximize

  # Get the dimensions of this window.
  #
  # Returns an {Object} with the following keys:
  #   * `x`      The window's x-position {Number}.
  #   * `y`      The window's y-position {Number}.
  #   * `width`  The window's width {Number}.
  #   * `height` The window's height {Number}.
  getWindowDimensions: ->
    browserWindow = @getCurrentWindow()
    [x, y] = browserWindow.getPosition()
    [width, height] = browserWindow.getSize()
    maximized = browserWindow.isMaximized()
    {x, y, width, height, maximized}

  # Set the dimensions of the window.
  #
  # The window will be centered if either the x or y coordinate is not set
  # in the dimensions parameter. If x or y are omitted the window will be
  # centered. If height or width are omitted only the position will be changed.
  #
  # * `dimensions` An {Object} with the following keys:
  #   * `x` The new x coordinate.
  #   * `y` The new y coordinate.
  #   * `width` The new width.
  #   * `height` The new height.
  setWindowDimensions: ({x, y, width, height}) ->
    if width? and height?
      @setSize(width, height)
    if x? and y?
      @setPosition(x, y)
    else
      @center()

  # Returns true if the dimensions are useable, false if they should be ignored.
  # Work around for https://github.com/atom/atom-shell/issues/473
  isValidDimensions: ({x, y, width, height}={}) ->
    width > 0 and height > 0 and x + width > 0 and y + height > 0

  storeDefaultWindowDimensions: ->
    return unless @isMainWindow()
    dimensions = @getWindowDimensions()
    if @isValidDimensions(dimensions)
      localStorage.setItem("defaultWindowDimensions", JSON.stringify(dimensions))

  getDefaultWindowDimensions: ->
    {windowDimensions} = @getLoadSettings()
    return windowDimensions if windowDimensions?

    dimensions = null
    try
      dimensions = JSON.parse(localStorage.getItem("defaultWindowDimensions"))
    catch error
      console.warn "Error parsing default window dimensions", error
      localStorage.removeItem("defaultWindowDimensions")

    if @isValidDimensions(dimensions)
      dimensions
    else
      screen = remote.require 'screen'
      {width, height} = screen.getPrimaryDisplay().workAreaSize
      {x: 0, y: 0, width, height}

  restoreWindowDimensions: ->
    dimensions = @savedState.windowDimensions
    unless @isValidDimensions(dimensions)
      dimensions = @getDefaultWindowDimensions()
    @setWindowDimensions(dimensions)
    dimensions

  storeWindowDimensions: ->
    dimensions = @getWindowDimensions()
    @savedState.windowDimensions = dimensions if @isValidDimensions(dimensions)

  # Call this method when establishing a real application window.
  startRootWindow: ->
    {resourcePath, safeMode} = @getLoadSettings()

    CommandInstaller = require './command-installer'
    CommandInstaller.installAtomCommand resourcePath, false, (error) ->
      console.warn error.message if error?
    CommandInstaller.installApmCommand resourcePath, false, (error) ->
      console.warn error.message if error?

    dimensions = @restoreWindowDimensions()

    @loadConfig()
    @keymaps.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @packages.loadPackages()
    @deserializeEditorWindow()
    @packages.activate()
    @keymaps.loadUserKeymap()
    @requireUserInitScript() unless safeMode
    @menu.update()

    @commands.add 'atom-workspace',
      'atom-workspace:add-account': =>
        @displayOnboardingWindow('add-account')
      'atom-workspace:logout': =>
        @logout()

    # Make sure we can't be made so small that the interface looks like crap
    @getCurrentWindow().setMinimumSize(875, 500)

    ipc.on 'onboarding-complete', =>
      maximize = dimensions?.maximized and process.platform isnt 'darwin'
      @displayWindow({maximize})

    if @isLoggedIn()
      maximize = dimensions?.maximized and process.platform isnt 'darwin'
      @displayWindow({maximize})
    else
      @displayOnboardingWindow()

  # Call this method when establishing a secondary application window
  # displaying a specific set of packages.
  #
  startSecondaryWindow: ->
    {width,
     height,
     windowType,
     windowProps,
     windowPackages} = @getLoadSettings()

    @loadConfig()
    @inbox.APIToken = atom.config.get('inbox.token')

    @keymaps.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @keymaps.loadUserKeymap()

    @packages.loadPackages(windowType)
    @packages.loadPackage(pack) for pack in (windowPackages ? [])
    @packages.activate()

    ipc.on("load-settings-changed", @loadSettingsChanged)
    @packages.windowPropsReceived(windowProps ? {})

    @keymaps.loadUserKeymap()

    @setWindowDimensions({width, height}) if width and height

    @menu.update()
    @subscribe @config.onDidChange 'core.autoHideMenuBar', ({newValue}) =>
      @setAutoHideMenuBar(newValue)
    @setAutoHideMenuBar(true) if @config.get('core.autoHideMenuBar')

  logout: ->
    if @isLoggedIn()
      @config.set('inbox', null)
      @config.set('edgehill', null)
      Actions = require './flux/actions'
      Actions.logout()
      @hide()
      @displayOnboardingWindow()

  # Requests that the backend browser bootup a new window with the given
  # options.
  # See the valid option types in AtomApplication::newWindow in
  # src/browser/edgehill-application.coffee
  newWindow: (options={}) -> ipc.send('new-window', options)

  # Registers a hot window for certain packages
  # See the valid option types in AtomApplication::registerHotWindow in
  # src/browser/edgehill-application.coffee
  registerHotWindow: (options={}) -> ipc.send('register-hot-window', options)

  displayOnboardingWindow: (page = false) ->
    options =
      title: 'Welcome to Edgehill'
      frame: false
      page: page
      width: 340
      height: 550
      resizable: false
      windowType: 'onboarding'
      windowPackages: ['onboarding']
    ipc.send('new-window', options)

  unloadEditorWindow: ->
    @packages.deactivatePackages()
    @savedState.packageStates = @packages.packageStates
    @saveSync()
    @windowState = null

  removeEditorWindow: ->
    @windowEventHandler?.unsubscribe()

  ###
  Section: Messaging the User
  ###

  # Essential: Visually and audibly trigger a beep.
  beep: ->
    shell.beep() if @config.get('core.audioBeep')
    @emitter.emit 'did-beep'

  playSound: (filename) ->
    return if @inSpecMode()
    {resourcePath} = atom.getLoadSettings()
    a = new Audio()
    a.src = path.join(resourcePath, 'static', 'sounds', filename)
    a.autoplay = true
    a.play()

  # Essential: A flexible way to open a dialog akin to an alert dialog.
  #
  # ## Examples
  #
  # ```coffee
  # atom.confirm
  #   message: 'How you feeling?'
  #   detailedMessage: 'Be honest.'
  #   buttons:
  #     Good: -> window.alert('good to hear')
  #     Bad: -> window.alert('bummer')
  # ```
  #
  # * `options` An {Object} with the following keys:
  #   * `message` The {String} message to display.
  #   * `detailedMessage` (optional) The {String} detailed message to display.
  #   * `buttons` (optional) Either an array of strings or an object where keys are
  #     button names and the values are callbacks to invoke when clicked.
  #
  # Returns the chosen button index {Number} if the buttons option was an array.
  confirm: ({message, detailedMessage, buttons}={}) ->
    buttons ?= {}
    if _.isArray(buttons)
      buttonLabels = buttons
    else
      buttonLabels = Object.keys(buttons)

    dialog = remote.require('dialog')
    chosen = dialog.showMessageBox @getCurrentWindow(),
      type: 'info'
      message: message
      detail: detailedMessage
      buttons: buttonLabels

    if _.isArray(buttons)
      chosen
    else
      callback = buttons[buttonLabels[chosen]]
      callback?()

  ###
  Section: Managing the Dev Tools
  ###

  # Extended: Open the dev tools for the current window.
  openDevTools: ->
    Actions = require './flux/actions'
    Actions.showDeveloperConsole()
    ipc.send('call-window-method', 'openDevTools')

  # Extended: Toggle the visibility of the dev tools for the current window.
  toggleDevTools: ->
    Actions = require './flux/actions'
    Actions.showDeveloperConsole()
    ipc.send('call-window-method', 'toggleDevTools')

  # Extended: Execute code in dev tools.
  executeJavaScriptInDevTools: (code) ->
    ipc.send('call-window-method', 'executeJavaScriptInDevTools', code)

  ###
  Section: Private
  ###

  deserializeWorkspaceView: ->
    startTime = Date.now()
    # Put state back into sheet-container? Restore app state here
    @deserializeTimings.workspace = Date.now() - startTime

    @item = document.createElement("atom-workspace")
    @item.setAttribute("id", "sheet-container")
    @item.setAttribute("class", "sheet-container")
    @item.setAttribute("tabIndex", "-1")

    React = require "react"
    SheetContainer = require './sheet-container'
    React.render(React.createElement(SheetContainer), @item)
    document.querySelector(@workspaceViewParentSelector).appendChild(@item)

  deserializePackageStates: ->
    @packages.packageStates = @savedState.packageStates ? {}
    delete @savedState.packageStates

  deserializeEditorWindow: ->
    @deserializePackageStates()
    @deserializeWorkspaceView()

  loadThemes: ->
    @themes.load()

  loadConfig: ->
    @config.setSchema null, {type: 'object', properties: _.clone(require('./config-schema'))}
    @config.load()

  watchThemes: ->
    @themes.onDidChangeActiveThemes =>
      # Only reload stylesheets from non-theme packages
      for pack in @packages.getActivePackages() when pack.getType() isnt 'theme'
        pack.reloadStylesheets?()
      null

  exit: (status) ->
    app = remote.require('app')
    app.emit('will-exit')
    remote.process.exit(status)

  showOpenDialog: (options, callback) ->
    parentWindow = if process.platform is 'darwin' then null else @getCurrentWindow()
    dialog = remote.require('dialog')
    dialog.showOpenDialog(parentWindow, options, callback)

  showSaveDialog: (defaultPath, callback) ->
    parentWindow = if process.platform is 'darwin' then null else @getCurrentWindow()
    dialog = remote.require('dialog')
    dialog.showSaveDialog(parentWindow, {title: 'Save File', defaultPath}, callback)

  saveSync: ->
    stateString = JSON.stringify(@savedState)
    if statePath = @constructor.getStatePath()
      fs.writeFileSync(statePath, stateString, 'utf8')
    else
      @getCurrentWindow().loadSettings.windowState = stateString

  crashMainProcess: ->
    remote.process.crash()

  crashRenderProcess: ->
    process.crash()

  getUserInitScriptPath: ->
    initScriptPath = fs.resolve(@getConfigDirPath(), 'init', ['js', 'coffee'])
    initScriptPath ? path.join(@getConfigDirPath(), 'init.coffee')

  requireUserInitScript: ->
    if userInitScriptPath = @getUserInitScriptPath()
      try
        require(userInitScriptPath) if fs.isFileSync(userInitScriptPath)
      catch error
        atom.notifications.addError "Failed to load `#{userInitScriptPath}`",
          detail: error.message
          dismissable: true

  # Require the module with the given globals.
  #
  # The globals will be set on the `window` object and removed after the
  # require completes.
  #
  # * `id` The {String} module name or path.
  # * `globals` An optinal {Object} to set as globals during require.
  requireWithGlobals: (id, globals={}) ->
    existingGlobals = {}
    for key, value of globals
      existingGlobals[key] = window[key]
      window[key] = value

    require(id)

    for key, value of existingGlobals
      if value is undefined
        delete window[key]
      else
        window[key] = value

  onUpdateAvailable: (callback) ->
    @emitter.on 'update-available', callback

  updateAvailable: (details) ->
    @emitter.emit 'update-available', details

  setBodyPlatformClass: ->
    document.body.classList.add("platform-#{process.platform}")

  setAutoHideMenuBar: (autoHide) ->
    ipc.send('call-window-method', 'setAutoHideMenuBar', autoHide)
    ipc.send('call-window-method', 'setMenuBarVisibility', !autoHide)

  onBeforeUnload: ->
    Actions = require './flux/actions'
    Actions.unloading()
