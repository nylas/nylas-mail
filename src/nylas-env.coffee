crypto = require 'crypto'
os = require 'os'
path = require 'path'

{ipcRenderer, remote, shell} = require 'electron'

_ = require 'underscore'
{deprecate} = require 'grim'
{Emitter} = require 'event-kit'
{Model} = require 'theorist'
fs = require 'fs-plus'
{convertStackTrace, convertLine} = require 'coffeestack'
{mapSourcePosition} = require 'source-map-support'

WindowEventHandler = require './window-event-handler'
StylesElement = require './styles-element'

Utils = require './flux/models/utils'
{APIError} = require './flux/errors'

ensureInteger = (f, fallback) ->
  if f is NaN or f is undefined or f is null
    f = fallback
  return Math.round(f)

# Essential: NylasEnv global for dealing with packages, themes, menus, and the window.
#
# The singleton of this class is always available as the `NylasEnv` global.
module.exports =
class NylasEnvConstructor extends Model
  @version: 1  # Increment this when the serialization format changes

  assert: (bool, msg) ->
    throw new Error("Assertion error: #{msg}") if not bool

  # Load or create the application environment
  # Returns an NylasEnv instance, fully initialized
  @loadOrCreate: ->
    startTime = Date.now()

    savedState = @_loadSavedState()
    if savedState and savedState?.version is @version
      app = new this(savedState)
    else
      app = new this({@version})

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
    {isSpec, mainWindow} = @getLoadSettings()
    if isSpec
      filename = 'spec-saved-state.json'
    else if mainWindow
      path.join(@getConfigDirPath(), 'main-window-state.json')
    else
      null

  # Get the directory path to NylasEnv's configuration area.
  #
  # Returns the absolute path to ~/.nylas
  @getConfigDirPath: ->
    @configDirPath ?= fs.absolute('~/.nylas')

  # Returns the load settings hash associated with the current window.
  @getLoadSettings: ->
    @loadSettings ?= JSON.parse(decodeURIComponent(location.search.substr(14)))

    cloned = Utils.deepClone(@loadSettings)
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

  # Public: A {PackageManager} instance
  packages: null

  # Public: A {ThemeManager} instance
  themes: null

  # Public: A {StyleManager} instance
  styles: null

  ###
  Section: Construction and Destruction
  ###

  # Call .loadOrCreate instead
  constructor: (@savedState={}) ->
    {@version} = @savedState
    @emitter = new Emitter

  # Sets up the basic services that should be available in all modes
  # (both spec and application).
  #
  # Call after this instance has been assigned to the `NylasEnv` global.
  initialize: ->
    # Disable deprecations unless in dev mode or spec mode so that regular
    # editor performance isn't impacted by generating stack traces for
    # deprecated calls.
    unless @inDevMode() or @inSpecMode()
      require('grim').deprecate = ->

    @enhanceEventObject()

    @setupErrorLogger()

    @unsubscribe()

    @loadTime = null

    Config = require './config'
    KeymapManager = require './keymap-manager'
    CommandRegistry = require './command-registry'
    PackageManager = require './package-manager'
    Clipboard = require './clipboard'
    ThemeManager = require './theme-manager'
    StyleManager = require './style-manager'
    ActionBridge = require './flux/action-bridge'
    MenuManager = require './menu-manager'
    configDirPath = @getConfigDirPath()

    {devMode, safeMode, resourcePath, windowType} = @getLoadSettings()

    document.body.classList.add("platform-#{process.platform}")
    document.body.classList.add("window-type-#{windowType}")

    # Add 'src/global' to module search path.
    globalPath = path.join(resourcePath, 'src', 'global')
    require('module').globalPaths.push(globalPath)

    # Still set NODE_PATH since tasks may need it.
    process.env.NODE_PATH = globalPath

    # Make react.js faster
    process.env.NODE_ENV ?= 'production' unless devMode

    # Set NylasEnv's home so packages don't have to guess it
    process.env.NYLAS_HOME = configDirPath

    # Setup config and load it immediately so it's available to our singletons
    @config = new Config({configDirPath, resourcePath})

    @keymaps = new KeymapManager({configDirPath, resourcePath})
    @keymaps.onDidMatchBinding (event) ->
      # If the user fired a command with the application: prefix bound to
      # the body, re-fire it up into the browser process. This prevents us
      # from needing this crap, which has to be updated every time a new
      # application: command is added:
      if event.binding.command.indexOf('application:') is 0 and event.binding.selector.indexOf("body") is 0
        ipcRenderer.send('command', event.binding.command)

    unless @inSpecMode()
      @actionBridge = new ActionBridge(ipcRenderer)

    @commands = new CommandRegistry
    specMode = @inSpecMode()
    @packages = new PackageManager({devMode, configDirPath, resourcePath, safeMode, specMode})
    @styles = new StyleManager
    document.head.appendChild(new StylesElement)
    @themes = new ThemeManager({packageManager: @packages, configDirPath, resourcePath, safeMode})
    @clipboard = new Clipboard()

    @menu = new MenuManager({resourcePath})
    if process.platform is 'win32'
      @getCurrentWindow().setMenuBarVisibility(false)

    # initialize spell checking
    require('web-frame').setSpellCheckProvider("en-US", false, {
      spellCheck: (text) ->
        !(require('spellchecker').isMisspelled(text))
    })

    @subscribe @packages.onDidActivateInitialPackages => @watchThemes()
    @windowEventHandler = new WindowEventHandler

    window.onbeforeunload = => @_unloading()
    @_unloadCallbacks = []

  # Start our error reporting to the backend and attach error handlers
  # to the window and the Bluebird Promise library, converting things
  # back through the sourcemap as necessary.
  setupErrorLogger: ->
    ErrorLogger = require './error-logger'
    @errorLogger = new ErrorLogger
      inSpecMode: @inSpecMode()
      inDevMode: @inDevMode()
      resourcePath: @getLoadSettings().resourcePath

    sourceMapCache = {}

    window.onerror = =>
      @lastUncaughtError = Array::slice.call(arguments)
      [message, url, line, column, originalError] = @lastUncaughtError

      # {line, column} = mapSourcePosition({source: url, line, column})

      eventObject = {message, url, line, column, originalError}

      openDevTools = true
      eventObject.preventDefault = -> openDevTools = false

      @emitter.emit 'will-throw-error', eventObject

      if openDevTools and @inDevMode()
        @openDevTools()
        @executeJavaScriptInDevTools('DevToolsAPI.showConsole()')

      @emitter.emit 'did-throw-error', {message, url, line, column, originalError}

    # Since Bluebird is the promise library, we can properly report
    # unhandled errors from business logic inside promises.
    Promise.longStackTraces() unless @inSpecMode()

    Promise.onPossiblyUnhandledRejection (error) =>
      error.stack = convertStackTrace(error.stack, sourceMapCache)

      # API Errors are logged to Sentry only under certain circumstances,
      # and are logged directly from the NylasAPI class.
      if error instanceof APIError
        return

      if @inSpecMode()
        console.error(error.stack)
      else if @inDevMode()
        console.error(error.message, error.stack, error)
        @openDevTools()
        @executeJavaScriptInDevTools('InspectorFrontendAPI.showConsole()')
      else
        console.warn(error)
        console.warn(error.stack)

      @emitError(error)

  emitError: (error) ->
    console.error(error) unless @inSpecMode()
    eventObject = {message: error.message, originalError: error}
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

  # Extended: Run the Chromium content-tracing module for five seconds, and save
  # the output to a file which is printed to the command-line output of the app.
  # You can take the file exported by this function and load it into Chrome's
  # content trace visualizer (chrome://tracing). It's like Chromium Developer
  # Tools Profiler, but for all processes and threads.
  trace: ->
    tracing = remote.require('content-tracing')
    tracing.startRecording '*', 'record-until-full,enable-sampling,enable-systrace', ->
      console.log('Tracing started')
      setTimeout ->
        tracing.stopRecording '', (path) ->
          console.log('Tracing data recorded to ' + path)
      , 5000

  isMainWindow: ->
    !!@getLoadSettings().mainWindow

  isWorkWindow: ->
    @getWindowType() is 'work'

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

  # Public: Get the version of N1.
  #
  # Returns the version text {String}.
  getVersion: ->
    @appVersion ?= @getLoadSettings().appVersion

  # Public: Determine whether the current version is an official release.
  isReleasedVersion: ->
    not /\w{7}/.test(@getVersion()) # Check if the release is a 7-character SHA prefix

  # Public: Get the directory path to N1's configuration area.
  #
  # Returns the absolute path to `~/.nylas`.
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
  Section: Managing The Nylas Window
  ###

  # Essential: Close the current window.
  close: ->
    @getCurrentWindow().close()

  quit: ->
    remote.require('app').quit()

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
    width = ensureInteger(width, 100)
    height = ensureInteger(height, 100)
    @getCurrentWindow().setSize(width, height)

  # Essential: Transition and set the size of the current window.
  #
  # * `width` The {Number} of pixels.
  # * `height` The {Number} of pixels.
  # * `duration` The {Number} of pixels.
  setSizeAnimated: (width, height, duration=400) ->
    # On Windows, the native window resizing code isn't fast enough to "animate"
    # by resizing over and over again. Just turn off animation for now.
    if process.platform is 'win32'
      duration = 1

    # Avoid divide by zero errors below
    duration = Math.max(1, duration)

    # Keep track of the number of times this method has been invoked, and ensure
    # that we only `tick` for the last invocation. This prevents two resizes from
    # running at the same time.
    @_setSizeAnimatedCallCount ?= 0
    @_setSizeAnimatedCallCount += 1
    call = @_setSizeAnimatedCallCount

    cubicInOut = (t) -> if t<.5 then 4*t**3 else (t-1)*(2*t-2)**2+1
    win = @getCurrentWindow()
    width = Math.round(width)
    height = Math.round(height)

    startBounds = win.getBounds()
    startTime = Date.now() - 1 # - 1 so that if duration is 1, t = 1 on the first frame

    boundsForI = (i) ->
      # It's very important this function never return undefined for any of the
      # keys which blows up setBounds.
      x: ensureInteger(startBounds.x + (width-startBounds.width) * -0.5 * i, 0)
      y: ensureInteger(startBounds.y + (height-startBounds.height) * -0.5 * i, 0)
      width: ensureInteger(startBounds.width + (width-startBounds.width) * i, width)
      height: ensureInteger(startBounds.height + (height-startBounds.height) * i, height)

    tick = =>
      return unless call is @_setSizeAnimatedCallCount
      t = Math.min(1, (Date.now() - startTime) / (duration))
      i = cubicInOut(t)
      win.setBounds(boundsForI(i))
      unless t is 1
        _.defer(tick)
    tick()

  setMinimumWidth: (minWidth) ->
    win = @getCurrentWindow()
    minWidth = ensureInteger(minWidth, 0)
    minHeight = win.getMinimumSize()[1]
    win.setMinimumSize(minWidth, minHeight)

    [currWidth, currHeight] = win.getSize()
    win.setSize(minWidth, currHeight) if minWidth > currWidth

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
    x = ensureInteger(x, 0)
    y = ensureInteger(y, 0)
    ipcRenderer.send('call-window-method', 'setPosition', x, y)

  # Extended: Get the current window
  getCurrentWindow: ->
    @constructor.getCurrentWindow()

  # Extended: Move current window to the center of the screen.
  center: ->
    ipcRenderer.send('call-window-method', 'center')

  # Extended: Focus the current window. Note: this will not open the window
  # if it is hidden.
  focus: ->
    ipcRenderer.send('call-window-method', 'focus')
    window.focus()

  # Extended: Show the current window.
  show: ->
    ipcRenderer.send('call-window-method', 'show')

  isVisible: ->
    @getCurrentWindow().isVisible()

  # Extended: Hide the current window.
  hide: ->
    ipcRenderer.send('call-window-method', 'hide')

  # Extended: Reload the current window.
  reload: ->
    ipcRenderer.send('call-window-method', 'restart')

  # Updates the window load settings - called when the app is ready to display
  # a hot-loaded window. Causes listeners registered with `onWindowPropsReceived`
  # to receive new window props.
  loadSettingsChanged: (event, loadSettings) =>
    @loadSettings = loadSettings
    @constructor.loadSettings = loadSettings
    {width, height, windowProps} = loadSettings

    @emitter.emit('window-props-received', windowProps ? {})

    if width and height
      @setWindowDimensions({width, height})

  # Public: The windowProps passed when creating the window via `newWindow`.
  #
  getWindowProps: ->
    @getLoadSettings().windowProps ? {}

  # Public: If your package declares hot-loaded window types, `onWindowPropsReceived`
  # fires when your hot-loaded window is about to be shown so you can update
  # components to reflect the new window props.
  #
  # - callback: A function to call when window props are received, just before
  #   the hot window is shown. The first parameter is the new windowProps.
  #
  onWindowPropsReceived: (callback) ->
    @emitter.on('window-props-received', callback)

  # Extended: Is the current window maximized?
  isMaximixed: ->
    @getCurrentWindow().isMaximized()

  maximize: ->
    ipcRenderer.send('call-window-method', 'maximize')

  minimize: ->
    ipcRenderer.send('call-window-method', 'minimize')

  # Extended: Is the current window in full screen mode?
  isFullScreen: ->
    @getCurrentWindow().isFullScreen()

  # Extended: Set the full screen state of the current window.
  setFullScreen: (fullScreen=false) ->
    ipcRenderer.send('call-window-method', 'setFullScreen', fullScreen)
    if fullScreen then document.body.classList.add("fullscreen") else document.body.classList.remove("fullscreen")

  # Extended: Toggle the full screen state of the current window.
  toggleFullScreen: ->
    @setFullScreen(!@isFullScreen())

  # Get the dimensions of this window.
  #
  # Returns an {Object} with the following keys:
  #   * `x`      The window's x-position {Number}.
  #   * `y`      The window's y-position {Number}.
  #   * `width`  The window's width {Number}.
  #   * `height` The window's height {Number}.
  getWindowDimensions: ->
    browserWindow = @getCurrentWindow()
    {x, y, width, height} = browserWindow.getBounds()
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
    if x? and y? and width? and height?
      @getCurrentWindow().setBounds({x, y, width, height})
    else if width? and height?
      @setSize(width, height)
    else if x? and y?
      @setPosition(x, y)
    else
      @center()

  # Returns true if the dimensions are useable, false if they should be ignored.
  # Work around for https://github.com/atom/electron/issues/473
  isValidDimensions: ({x, y, width, height}={}) ->
    width > 0 and height > 0 and x + width > 0 and y + height > 0

  getDefaultWindowDimensions: ->
    screen = remote.require('screen')
    {width, height} = screen.getPrimaryDisplay().workAreaSize
    x = 0
    y = 0

    MAX_WIDTH = 1440
    if width > MAX_WIDTH
      x = Math.floor((width - MAX_WIDTH) / 2)
      width = MAX_WIDTH

    MAX_HEIGHT = 900
    if height > MAX_HEIGHT
      y = Math.floor((height - MAX_HEIGHT) / 2)
      height = MAX_HEIGHT

    {x, y, width, height}

  restoreWindowDimensions: ->
    dimensions = @savedState.windowDimensions
    unless @isValidDimensions(dimensions)
      dimensions = @getDefaultWindowDimensions()
    @setWindowDimensions(dimensions)
    @maximize() if dimensions.maximized and process.platform isnt 'darwin'

  storeWindowDimensions: ->
    dimensions = @getWindowDimensions()
    @savedState.windowDimensions = dimensions if @isValidDimensions(dimensions)

  # Call this method when establishing a real application window.
  startRootWindow: ->
    @displayWindow()

    {safeMode, windowType} = @getLoadSettings()
    @registerCommands()
    @loadConfig()
    @keymaps.loadBundledKeymaps()
    @themes.loadBaseStylesheets()
    @packages.loadPackages(windowType)
    @deserializePackageStates()
    @deserializeSheetContainer()
    @packages.activate()
    @keymaps.loadUserKeymap()
    @requireUserInitScript() unless safeMode
    @menu.update()

    @showRootWindow()

    ipcRenderer.send('window-command', 'window:loaded')

  showRootWindow: ->
    cover = document.getElementById("application-loading-cover")
    cover.classList.add('visible')
    @restoreWindowDimensions()
    @getCurrentWindow().setMinimumSize(875, 500)

  registerCommands: ->
    {resourcePath} = @getLoadSettings()
    CommandInstaller = require './command-installer'
    CommandInstaller.installN1Command resourcePath, false, (error) ->
      console.warn error.message if error?
    CommandInstaller.installApmCommand resourcePath, false, (error) ->
      console.warn error.message if error?

  # Call this method when establishing a secondary application window
  # displaying a specific set of packages.
  #
  startSecondaryWindow: ->
    {width,
     height,
     windowType,
     windowPackages} = @getLoadSettings()

    cover = document.getElementById("application-loading-cover")
    cover.remove() if cover

    @loadConfig()

    @keymaps.loadBundledKeymaps()
    @themes.loadBaseStylesheets()

    @packages.loadPackages(windowType)
    @packages.loadPackage(pack) for pack in (windowPackages ? [])
    @deserializeSheetContainer()
    @packages.activate()
    @keymaps.loadUserKeymap()

    ipcRenderer.on("load-settings-changed", @loadSettingsChanged)

    @setWindowDimensions({width, height}) if width and height

    @menu.update()

    ipcRenderer.send('window-command', 'window:loaded')

  # Requests that the backend browser bootup a new window with the given
  # options.
  # See the valid option types in Application::newWindow in
  # src/browser/application.coffee
  newWindow: (options={}) -> ipcRenderer.send('new-window', options)

  # Registers a hot window for certain packages
  # See the valid option types in Application::registerHotWindow in
  # src/browser/application.coffee
  registerHotWindow: (options={}) -> ipcRenderer.send('register-hot-window', options)

  # Unregisters a hot window with the given windowType
  unregisterHotWindow: (windowType) -> ipcRenderer.send('unregister-hot-window', windowType)

  saveStateAndUnloadWindow: ->
    @packages.deactivatePackages()
    @savedState.packageStates = @packages.packageStates
    @saveSync()
    @windowState = null

  ###
  Section: Messaging the User
  ###

  displayWindow: ({maximize} = {}) ->
    @show()
    @focus()
    @maximize() if maximize

  # Essential: Visually and audibly trigger a beep.
  beep: ->
    shell.beep() if @config.get('core.audioBeep')
    @emitter.emit 'did-beep'

  # Essential: A flexible way to open a dialog akin to an alert dialog.
  #
  # ## Examples
  #
  # ```coffee
  # NylasEnv.confirm
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
    ipcRenderer.send('call-window-method', 'openDevTools')

  # Extended: Toggle the visibility of the dev tools for the current window.
  toggleDevTools: ->
    ipcRenderer.send('call-window-method', 'toggleDevTools')

  # Extended: Execute code in dev tools.
  executeJavaScriptInDevTools: (code) ->
    ipcRenderer.send('call-webcontents-method', 'executeJavaScriptInDevTools', code)

  ###
  Section: Private
  ###

  deserializeSheetContainer: ->
    startTime = Date.now()
    # Put state back into sheet-container? Restore app state here
    @item = document.createElement("nylas-workspace")
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
    dialog = remote.require('dialog')
    callback(dialog.showOpenDialog(@getCurrentWindow(), options))

  showSaveDialog: (options, callback) ->
    options.title ?= 'Save File'
    dialog = remote.require('dialog')
    callback(dialog.showSaveDialog(@getCurrentWindow(), options))

  showErrorDialog: (message) ->
    dialog = remote.require('dialog')
    dialog.showMessageBox null, {
      type: 'warning'
      buttons: ['Okay'],
      message: "Error"
      detail: message
    }

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
        console.log(error)

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

  # Lets multiple components register beforeUnload callbacks.
  # The callbacks are expected to return either true or false.
  #
  # Note: If you return false to cancel the window close, you /must/ perform
  # work and then call finishUnload. We do not support cancelling quit!
  # https://phab.nylas.com/D1932#inline-11722
  #
  onBeforeUnload: (callback) -> @_unloadCallbacks.push(callback)

  _unloading: ->
    continueUnload = true
    for callback in @_unloadCallbacks
      returnValue = callback()
      if returnValue is true
        continue
      else if returnValue is false
        continueUnload = false
      else
        console.warn "You registered an `onBeforeUnload` callback that does not return either exactly `true` or `false`. It returned #{returnValue}", callback
    return continueUnload

  # Call this method to resume the close / quit process if you returned
  # false from a onBeforeUnload handler.
  #
  finishUnload: ->
    _.defer =>
      if remote.getGlobal('application').quitting
        remote.require('app').quit()
      else
        @close()

  enhanceEventObject: ->
    overriddenStop =  Event::stopPropagation
    Event::stopPropagation = ->
      @propagationStopped = true
      overriddenStop.apply(@, arguments)
    Event::isPropagationStopped = ->
      @propagationStopped
