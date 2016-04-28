_ = require 'underscore'
fs = require 'fs-plus'
NylasWindow = require './nylas-window'
WindowLauncher = require './window-launcher'

{BrowserWindow, app} = require 'electron'

class WindowManager

  @MAIN_WINDOW: "default"
  @WORK_WINDOW: "work"
  @SPEC_WINDOW: "spec"
  @ONBOARDING_WINDOW: "onboarding"

  constructor: (appOpts) ->
    {@initializeInBackground} = appOpts
    @_windows = {}
    @windowLauncher = new WindowLauncher(appOpts)

    # Be sure to register the very first hot window! If you don't, then
    # the first window (only) won't get window events (like being notified
    # the database is setup), which causes components loaded in that
    # window to not work and may even prevent window closure (like in the
    # case of the composer)
    @_registerWindow(@windowLauncher.hotWindow)
    @_didCreateNewWindow(@windowLauncher.hotWindow)

  get: (windowKey) -> @_windows[windowKey]

  getOpenWindows: ->
    values = []
    for key, win of @_windows
      continue unless win.isVisible() || win.isMinimized()
      values.push(win)

    score = (win) -> if win.loadSettings().mainWindow then 1000 else win.browserWindow.id
    return values.sort (a, b) -> score(b) - score(a)

  newWindow: (options={}) ->
    win = @windowLauncher.newWindow(options)

    existingKey = @_registeredKeyForWindow(win)
    delete @_windows[existingKey] if existingKey
    @_registerWindow(win)

    if not existingKey
      @_didCreateNewWindow(win)

    return win

  _registerWindow: (win) =>
    unless win.windowKey
      throw new Error("WindowManager: You must provide a windowKey")

    if @_windows[win.windowKey]
      throw new Error("WindowManager: Attempting to register a new window for an existing windowKey (#{win.windowKey}). Use `get()` to retrieve the existing window instead.")

    @_windows[win.windowKey] = win

  _didCreateNewWindow: (win) =>
    win.browserWindow.on "closed", =>
      delete @_windows[win.windowKey]
      @quitWinLinuxIfNoWindows()

    # Let the applicationMenu know that there's a new window available.
    # The applicationMenu automatically listens to the `closed` event of
    # the browserWindow to unregister itself
    global.application.applicationMenu.addWindow(win.browserWindow)

  _registeredKeyForWindow: (win) =>
    for key, otherWin of @_windows
      if win is otherWin
        return key
    return null

  ensureWindow: (windowKey, extraOpts) ->
    win = @_windows[windowKey]
    if win
      return if win.loadSettings().hidden
      if win.isMinimized()
        win.restore()
        win.focus()
      else if !win.isVisible()
        win.showWhenLoaded()
      else
        win.focus()
    else
      @newWindow(@_coreWindowOpts(windowKey, extraOpts))

  sendToWindow: (windowKey, args...) ->
    if not @_windows[windowKey]
      throw new Error("Can't find window: #{windowKey}")
    @_windows[windowKey].sendMessage(args...)

  sendToAllWindows: (msg, {except}, args...) ->
    for windowKey, win of @_windows
      continue if win.browserWindow == except
      continue unless win.browserWindow.webContents
      win.browserWindow.webContents.send(msg, args...)

  closeAllWindows: ->
    win.close() for windowKey, win of @_windows

  cleanupBeforeAppQuit: -> @windowLauncher.cleanupBeforeAppQuit()

  quitWinLinuxIfNoWindows: ->
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
        visibleWindows = _.filter(@_windows, (win) -> win.isVisible())
        noMainWindowLoaded = not @get(WindowManager.MAIN_WINDOW)?.isLoaded()
        if visibleWindows.length is 0 and noMainWindowLoaded
          app.quit()
      , 10000
      @quitCheck()

  focusedWindow: -> _.find(@_windows, (win) -> win.isFocused())

  _coreWindowOpts: (windowKey, extraOpts={}) ->
    coreWinOpts = {}
    coreWinOpts[WindowManager.MAIN_WINDOW] =
      windowKey: WindowManager.MAIN_WINDOW
      windowType: WindowManager.MAIN_WINDOW
      title: "Message Viewer"
      neverClose: true
      bootstrapScript: require.resolve("../window-bootstrap")
      mainWindow: true
      width: 640 # Gets reset once app boots up
      height: 396 # Gets reset once app boots up
      center: true # Gets reset once app boots up
      resizable: false # Gets reset once app boots up
      initializeInBackground: @initializeInBackground

    coreWinOpts[WindowManager.WORK_WINDOW] =
      windowKey: WindowManager.WORK_WINDOW
      windowType: WindowManager.WORK_WINDOW
      coldStartOnly: true # It's a secondary window, but not a hot window
      title: "Activity"
      hidden: true
      neverClose: true
      width: 800
      height: 400

    coreWinOpts[WindowManager.ONBOARDING_WINDOW] =
      windowKey: WindowManager.ONBOARDING_WINDOW
      windowType: WindowManager.ONBOARDING_WINDOW
      title: "Account Setup"
      hidden: true # Displayed by PageRouter::_initializeWindowSize
      frame: false # Always false on Mac, explicitly set for Win & Linux
      toolbar: false
      resizable: false

    # The SPEC_WINDOW gets passed its own bootstrapScript
    coreWinOpts[WindowManager.SPEC_WINDOW] =
      windowKey: WindowManager.SPEC_WINDOW
      windowType: WindowManager.SPEC_WINDOW
      title: "Specs"
      frame: true,
      hidden: true,
      isSpec: true,
      devMode: true,
      toolbar: false

    defaultOptions = coreWinOpts[windowKey] ? {}

    return Object.assign({}, defaultOptions, extraOpts)

module.exports = WindowManager
