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
    {isSpec, mainWindow, configDirPath} = @getLoadSettings()
    if isSpec
      filename = 'spec-saved-state.json'
    else if mainWindow
      path.join(configDirPath, 'main-window-state.json')
    else
      null

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

    {devMode, safeMode, resourcePath, configDirPath, windowType} = @getLoadSettings()

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

    @commands = new CommandRegistry
    @commands.attach(window)

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
    @spellchecker = require('./nylas-spellchecker')

    @subscribe @packages.onDidActivateInitialPackages => @watchThemes()
    @windowEventHandler = new WindowEventHandler()

    unless @inSpecMode()
      @actionBridge = new ActionBridge(ipcRenderer)

  # This ties window.onerror and Promise.onPossiblyUnhandledRejection to
  # the publically callable `reportError` method. This will take care of
  # reporting errors if necessary and hooking into error handling
  # callbacks.
  #
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

    # https://developer.mozilla.org/en-US/docs/Web/API/GlobalEventHandlers/onerror
    window.onerror = =>
      args = Array::slice.call(arguments)
      [message, url, line, column, originalError] = args
      {line, column} = mapSourcePosition({source: url, line, column})
      originalError.stack = convertStackTrace(originalError.stack, sourceMapCache)
      @reportError(originalError, {url, line, column})

    Promise.onPossiblyUnhandledRejection (error, promise) =>
      error.stack = convertStackTrace(error.stack, sourceMapCache)

      # API Errors are logged to Sentry only under certain circumstances,
      # and are logged directly from the NylasAPI class.
      if error instanceof APIError
        return if error.statusCode isnt 400

      @reportError(error, {promise})

    if @inSpecMode() or @inDevMode()
      Promise.longStackTraces()

  _createErrorCallbackEvent: (error, extraArgs={}) ->
    event = _.extend({}, extraArgs, {
      message: error.message
      originalError: error
      defaultPrevented: false
    })
    event.preventDefault = -> event.defaultPrevented = true
    return event

  # Public: report an error through the `ErrorLogger`
  #
  # Takes an error and an extra object to report. Hooks into the
  # `onWillThrowError` and `onDidThrowError` callbacks. If someone
  # registered with `onWillThrowError` calls `preventDefault` on the event
  # object it's given, then no error will be reported.
  #
  # The difference between this and `ErrorLogger.reportError` is that
  # `NylasEnv.reportError` will hook into the event callbacks and handle
  # test failures and dev tool popups.
  reportError: (error, extra={}) ->
    event = @_createErrorCallbackEvent(error, extra)
    @emitter.emit('will-throw-error', event)
    return if event.defaultPrevented

    console.error(error.stack)
    @lastUncaughtError = error

    extra.pluginIds = @_findPluginsFromError(error)

    if @inSpecMode()
      jasmine.getEnv().currentSpec.fail(error)
    else if @inDevMode()
      @openDevTools()
      @executeJavaScriptInDevTools('InspectorFrontendAPI.showConsole()')

    @errorLogger.reportError(error, extra)

    @emitter.emit('did-throw-error', event)

  _findPluginsFromError: (error) ->
    return [] unless error.stack
    stackPaths = error.stack.match(/((?:\/[\w-_]+)+)/g) ? []
    stackTokens = _.uniq(_.flatten(stackPaths.map((p) -> p.split("/"))))
    pluginIdsByPathBase = @packages.getPluginIdsByPathBase()
    tokens = _.intersection(Object.keys(pluginIdsByPathBase), stackTokens)
    return tokens.map((tok) -> pluginIdsByPathBase[tok])

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
    tracing = remote.require('electron').contentTracing
    opts =
      categoryFilter: '*',
      traceOptions: 'record-until-full,enable-sampling,enable-systrace',
    tracing.startRecording opts, ->
      console.log('Tracing started')
      setTimeout ->
        tracing.stopRecording '', (path) ->
          console.log('Tracing data recorded to ' + path)
      , 5000

  isMainWindow: ->
    !!@getLoadSettings().mainWindow

  isWorkWindow: ->
    @getWindowType() is 'work'

  isComposerWindow: ->
    @getWindowType() is 'composer'

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
  getConfigDirPath: => @getLoadSettings().configDirPath

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
    ipcRenderer.send('call-webcontents-method', 'reload')

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
    fullScreen = browserWindow.isFullScreen()
    {x, y, width, height, maximized, fullScreen}

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
    @setFullScreen(true) if dimensions.fullScreen

  storeWindowDimensions: ->
    dimensions = @getWindowDimensions()
    @savedState.windowDimensions = dimensions if @isValidDimensions(dimensions)

  storeColumnWidth: ({id, width}) =>
    @savedState.columnWidths ?= {}
    @savedState.columnWidths[id] = width

  getColumnWidth: (id) =>
    @savedState.columnWidths ?= {}
    @savedState.columnWidths[id]

  # Call this method when establishing a real application window.
  startRootWindow: ->
    {safeMode, windowType, initializeInBackground} = @getLoadSettings()

    # Temporary. It takes five paint cycles for all the CSS in index.html to
    # be applied. Remove if https://github.com/atom/brightray/issues/196 fixed!
    window.requestAnimationFrame =>
      window.requestAnimationFrame =>
        window.requestAnimationFrame =>
          window.requestAnimationFrame =>
            window.requestAnimationFrame =>
              @displayWindow() unless initializeInBackground

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
    document.getElementById("application-loading-cover").remove()
    document.body.classList.add("window-loaded")
    @restoreWindowDimensions()
    @getCurrentWindow().setMinimumSize(875, 250)

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

    chosen = remote.dialog.showMessageBox @getCurrentWindow(),
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
    ipcRenderer.send('call-webcontents-method', 'openDevTools')

  # Extended: Toggle the visibility of the dev tools for the current window.
  toggleDevTools: ->
    ipcRenderer.send('call-webcontents-method', 'toggleDevTools')

  # Extended: Execute code in dev tools.
  executeJavaScriptInDevTools: (code) ->
    ipcRenderer.send('call-devtools-webcontents-method', 'executeJavaScript', code)

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
    ReactDOM = require "react-dom"
    SheetContainer = require './sheet-container'
    ReactDOM.render(React.createElement(SheetContainer), @item)
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
    callback(remote.dialog.showOpenDialog(@getCurrentWindow(), options))

  showSaveDialog: (options, callback) ->
    options.title ?= 'Save File'
    callback(remote.dialog.showSaveDialog(@getCurrentWindow(), options))

  showErrorDialog: (messageData, {showInMainWindow}={}) ->
    if _.isString(messageData) or _.isNumber(messageData)
      message = messageData
      title = "Error"
    else if _.isObject(messageData)
      message = messageData.message
      title = messageData.title
    else
      throw new Error("Must pass a valid message to show dialog", message)

    winToShow = null
    if showInMainWindow
      winToShow = remote.getGlobal('application').getMainWindow()

    remote.dialog.showMessageBox winToShow, {
      type: 'warning'
      buttons: ['Okay'],
      message: title
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
  onBeforeUnload: (callback) ->
    @windowEventHandler.addUnloadCallback(callback)

  enhanceEventObject: ->
    overriddenStop =  Event::stopPropagation
    Event::stopPropagation = ->
      @propagationStopped = true
      overriddenStop.apply(@, arguments)
    Event::isPropagationStopped = ->
      @propagationStopped
