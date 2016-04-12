_ = require 'underscore'
fs = require 'fs-plus'
NylasWindow = require './nylas-window'

{BrowserWindow, app} = require 'electron'

class WindowManager

  constructor: ({@devMode, @safeMode, @resourcePath, @configDirPath, @config, @initializeInBackground}) ->
    @_windows = []
    @_mainWindow = null
    @_workWindow = null
    @_hotWindows = {}

  closeAllWindows: ->
    @closeMainWindow()
    @closeWorkWindow()
    @unregisterAllHotWindows()
    for win in @_windows
      win.close()

  windows: ->
    @_windows

  windowWithPropsMatching: (props) ->
    _.find @_windows, (nylasWindow) ->
      {windowProps} = nylasWindow.loadSettings()
      return false unless windowProps
      _.every Object.keys(props), (key) -> _.isEqual(props[key],windowProps[key])

  focusedWindow: ->
    _.find @_windows, (nylasWindow) -> nylasWindow.isFocused()

  visibleWindows: ->
    _.filter @_windows, (nylasWindow) -> nylasWindow.isVisible()

  ###
  Main Window

  The main window is different from the others, because only one can exist at any
  given time and it is hidden instead of closed so that mail processing still
  happens.
  ###

  mainWindow: ->
    @_mainWindow

  sendToMainWindow: ->
    return unless @_mainWindow
    @_mainWindow.sendMessage(arguments...)

  closeMainWindow: ->
    return unless @_mainWindow
    @_mainWindow.neverClose = false
    @_mainWindow.close()
    @_mainWindow = null

  showMainWindow: (loadingMessage) ->
    if @_mainWindow
      if @_mainWindow.isMinimized()
        @_mainWindow.restore()
        @_mainWindow.focus()
      else if !@_mainWindow.isVisible()
        @_mainWindow.showWhenLoaded()
      else
        @_mainWindow.focus()

    else
      if @devMode
        try
          bootstrapScript = require.resolve(path.join(@resourcePath, 'src', 'window-bootstrap'))
          resourcePath = @resourcePath
      bootstrapScript ?= require.resolve('../window-bootstrap')
      resourcePath ?= @resourcePath

      @_mainWindow = new NylasWindow _.extend {}, @defaultWindowOptions(),
        loadingMessage: loadingMessage
        bootstrapScript: bootstrapScript
        neverClose: true
        mainWindow: true
        windowType: 'default'
        initializeInBackground: @initializeInBackground
        # The position and resizable bit gets reset when the window
        # finishes loading. This represents the state of our "loading"
        # window.
        center: true
        width: 640
        height: 396
        resizable: false

  ###
  Work Window
  ###

  workWindow: ->
    @_workWindow

  closeWorkWindow: ->
    return unless @_workWindow
    @_workWindow.neverClose = false
    @_workWindow.close()
    @_workWindow = null

  ensureWorkWindow: ->
    @_workWindow ?= @newWindow
      windowType: 'work'
      title: 'Activity'
      toolbar: true
      neverClose: true
      width: 800
      height: 400
      hidden: true

  showWorkWindow: ->
    return unless @_workWindow
    if @_workWindow.isMinimized()
      @_workWindow.restore()
      @_workWindow.focus()
    else if !@_workWindow.isVisible()
      @_workWindow.showWhenLoaded()
    else
      @_workWindow.focus()

  ###
  Onboarding Window

  The onboarding window is a normal secondary window, but the WindowManager knows
  how to create it itself.
  ###

  onboardingWindow: ->
    @windowWithPropsMatching({uniqueId: 'onboarding'})

  # Returns a new onboarding window
  #
  ensureOnboardingWindow: ({welcome, provider}={}) ->
    existing = @onboardingWindow()
    if existing
      existing.focus()
    else
      options =
        title: "Add an Account"
        toolbar: false
        resizable: false
        hidden: true # The `PageRouter` will center and show on load
        windowType: 'onboarding'
        windowProps:
          page: 'account-choose'
          uniqueId: 'onboarding'
          pageData: {provider}

      if welcome
        options.title = "Welcome to N1"
        options.windowProps.page = 'welcome'

      @newWindow(options)

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
  # reload.
  #
  # To listen for window props being sent to your existing hot-loaded window,
  # add a callback to `NylasEnv.onWindowPropsChanged`.
  #
  # Since the window is already loaded, there are only some options that
  # can be soft-reloaded. If you attempt to pass options that a soft
  # reload doesn't support, you'll be forced to load from a `coldStart`.
  #
  # Any options passed in here will be passed into the NylasWindow
  # constructor, which will eventually show up in the window's main
  # loadSettings, which is accessible via `NylasEnv.getLoadSettings()`
  #
  # REQUIRED options:
  #   - windowType: defaults "popout". This eventually ends up as
  #     NylasEnv.getWindowType()
  #
  # Valid options:
  #   - coldStart: true
  #   - windowProps: A good place to put any data components of the window
  #       need to initialize properly. NOTE: You can only put JSON
  #       serializable data. No functions!
  #   - title: The title of the page
  #
  # Other non required options:
  #   - All of the options of BrowserWindow
  #     https://github.com/atom/electron/blob/master/docs/api/browser-window.md#new-browserwindowoptions
  #
  # Returns a new NylasWindow
  #
  newWindow: (options={}) ->
    if options.coldStart or not @_hotWindows[options.windowType]?
      return @newColdWindow(options)
    else
      return @newHotWindow(options)

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
  #
  registerHotWindow: ({windowType, replenishNum, windowPackages, windowOptions}={}) ->
    if not windowType
      throw new Error("registerHotWindow: please provide a windowType")

    @_hotWindows ?= {}
    @_hotWindows[windowType] ?= {}
    @_hotWindows[windowType].replenishNum ?= (replenishNum ? 1)
    @_hotWindows[windowType].loadedWindows ?= []
    @_hotWindows[windowType].windowPackages ?= (windowPackages ? [])
    @_hotWindows[windowType].windowOptions ?= (windowOptions ? {})

    @_replenishHotWindows()

  unregisterHotWindow: (windowType) ->
    return unless @_hotWindows[windowType]

    # Remove entries from the replentishQueue
    @_replenishQueue = _.reject @_replenishQueue, (item) => item.windowType is windowType

    # Destroy any hot windows already loaded
    destroyedLoadingWindow = false
    {loadedWindows} = @_hotWindows[windowType]
    for win in loadedWindows
      destroyedLoadingWindow = true if not win.isLoaded()
      win.browserWindow.destroy()

    # Delete the hot window configuration
    delete @_hotWindows[windowType]

    # If we destroyed a window that was currently loading,
    # the queue will stop processing forever.
    if destroyedLoadingWindow
      @_processingQueue = false
      @_processReplenishQueue()

  # Immediately close all of the hot windows and reset the replentish queue
  # to prevent more from being opened without additional calls to registerHotWindow.
  #
  # Note: This method calls `browserWindow.destroy()` which closes windows without
  # waiting for them to load or firing window lifecycle events. This is necessary
  # for the app to quit promptly on Linux. https://phab.nylas.com/T1282
  #
  unregisterAllHotWindows: ->
    for type, {loadedWindows} of @_hotWindows
      for win in loadedWindows
        win.browserWindow.destroy()
    @_replenishQueue = []
    @_hotWindows = {}

  defaultWindowOptions: ->
    #TODO: Defaults are also applied in NylasWindow.constructor.
    devMode: @devMode
    safeMode: @safeMode
    windowType: 'popout'
    resourcePath: @resourcePath
    configDirPath: @configDirPath
    bootstrapScript: require.resolve("../window-secondary-bootstrap")

  newColdWindow: (options={}) ->
    options = _.extend(@defaultWindowOptions(), options)
    win = new NylasWindow(options)
    newLoadSettings = _.extend(win.loadSettings(), options)
    win.setLoadSettings(newLoadSettings)
    win.showWhenLoaded() unless options.hidden
    return win

  # Tries to create a new hot window. Since we're updating an existing
  # window instead of creatinga new one, there are limitations in the
  # options you can provide.
  #
  # Returns a new NylasWindow
  #
  newHotWindow: (options={}) ->
    hotWindowParams = @_hotWindows[options.windowType]
    win = null

    if not hotWindowParams?
      console.log "WindowManager: Warning! The requested windowType
      '#{options.windowType}' has not been registered. Be sure to call
      `registerWindowType` first in your packages setup."
      return @newColdWindow(options)

    supportedHotWindowKeys = [
      "x"
      "y"
      "title"
      "width"
      "height"
      "bounds"
      "windowType"
      "windowProps"
    ]

    unsupported =  _.difference(Object.keys(options), supportedHotWindowKeys)

    if unsupported.length > 0
      console.log "WindowManager: For the winodw of type
      #{options.windowType}, you are passing options that can't be
      applied to the preloaded window (#{JSON.stringify(unsupported)}).
      Please change the options or pass the `coldStart:true` option to use
      a new window instead of a hot window. If it's just data for the
      window, please put them in the `windowProps` param."

    if hotWindowParams.loadedWindows.length is 0
      # No windows ready
      console.log "No windows ready. Loading a new coldWindow"
      options.windowPackages = hotWindowParams.windowPackages
      win = @newColdWindow(options)
    else
      [win] = hotWindowParams.loadedWindows.splice(0,1)

      newLoadSettings = _.extend(win.loadSettings(), options)
      win.setLoadSettings(newLoadSettings)

      win.browserWindow.setTitle options.title ? ""

      if options.x and options.y
        win.browserWindow.setPosition options.x, options.w

      if options.width or options.height
        [w,h] = win.browserWindow.getSize()
        w = options.width ? w
        h = options.height ? h
        win.browserWindow.setSize(w,h)

      if options.bounds
        win.browserWindow.setBounds options.bounds

    @_replenishHotWindows()

    return win

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
    for windowType, data of @_hotWindows
      numOfType = data.replenishNum - data.loadedWindows.length
      maxWin = Math.max(numOfType, maxWin)
      if numOfType > 0
        options = _.extend {}, @defaultWindowOptions(), data.windowOptions
        options.windowType = windowType
        options.windowPackages = data.windowPackages
        queues[windowType] ?= []
        queues[windowType].push(options) for [0...numOfType]

    for [0...maxWin]
      for windowType, optionsArray of queues
        if optionsArray.length > 0
          @_replenishQueue.push(optionsArray.shift())

    @_processReplenishQueue()

  _replenishHotWindows: _.debounce(WindowManager::__replenishHotWindows, 100)

  _processReplenishQueue: ->
    return if @_processingQueue
    @_processingQueue = true
    if @_replenishQueue.length > 0
      options = @_replenishQueue.shift()
      console.log "WindowManager: Preparing a new '#{options.windowType}' window"
      newWindow = new NylasWindow(options)
      @_hotWindows[options.windowType].loadedWindows.push(newWindow)
      newWindow.once 'window:loaded', =>
        @_processingQueue = false
        @_processReplenishQueue()
    else
      @_processingQueue = false


  ###
  Methods called from NylasWindow
  ###

  # Public: Removes the {NylasWindow} from the global window list.
  removeWindow: (window) ->
    @_windows.splice @_windows.indexOf(window), 1
    if window is @_mainWindow
      @_mainWindow = null
    if window is @_workWindow
      @_workWindow = null
    @applicationMenu?.enableWindowSpecificItems(false) if @_windows.length == 0
    @windowClosedOrHidden()

  # Public: Adds the {NylasWindow} to the global window list.
  # IMPORTANT: NylasWindows add themselves - you don't need to manually add them
  addWindow: (window) ->
    @_windows.push window
    global.application.applicationMenu?.addWindow(window.browserWindow)
    window.once 'window:loaded', =>
      global.application.autoUpdateManager.emitUpdateAvailableEvent(window)

    unless window.isSpec
      closePreventedHandler = => @windowClosedOrHidden()
      window.on 'window:close-prevented', closePreventedHandler
      window.browserWindow.once 'closed', =>
        window.removeListener('window:close-prevented', closePreventedHandler)

  windowClosedOrHidden: ->
    # Typically, N1 stays running in the background on all platforms, since it
    # has a status icon you can use to quit it.
    #
    # However, on Windows and Linux we /do/ want to quit if the app is somehow
    # put into a state where there are no visible windows and the main window
    # doesn't exist.
    #
    # This /shouldn't/ happen, but if it does, the only way for them to recover
    # would be to pull up the Task Manager. Ew.
    #
    if process.platform in ['win32', 'linux']
      @quitCheck ?= _.debounce =>
        noVisibleWindows = @visibleWindows().length is 0
        noMainWindowLoaded = not @mainWindow()?.isLoaded()
        if noVisibleWindows and noMainWindowLoaded
          app.quit()
      , 10000
      @quitCheck()


module.exports = WindowManager
