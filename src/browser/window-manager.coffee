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

  get: (winId) -> @_windows[winId]

  newWindow: (options={}) ->
    win = @windowLauncher.newWindow(options)
    @_registerWindow(win)
    return win

  _registerWindow: (win) =>
    @_windows[win.windowKey] = win
    win.browserWindow.on "closed", =>
      delete @_windows[win.windowKey]
      @quitWinLinuxIfNoWindows()

  ensureWindow: (winId, extraOpts) ->
    win = @_windows[winId]
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
      @newWindow(@_coreWindowOpts(winId, extraOpts))

  sendToWindow: (winId, args...) ->
    if not @_windows[winId]
      throw new Error("Can't find window: #{winId}")
    @_windows[winId].sendMessage(args...)

  sendToAllWindows: (msg, {except}, args...) ->
    for winId, win of @_windows
      continue if win.browserWindow == except
      continue unless win.browserWindow.webContents
      win.browserWindow.webContents.send(msg, args...)

  closeAllWindows: ->
    win.close() for winId, win of @_windows

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

  _coreWindowOpts: (winId, extraOpts={}) ->
    coreWinOpts = {}
    coreWinOpts[WindowManager.MAIN_WINDOW] =
      windowKey: WindowManager.MAIN_WINDOW
      windowType: WindowManager.MAIN_WINDOW
      title: "Nylas N1"
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
      hidden: true # Displayed by PageRouter::_initializeWindowSize
      frame: false # Always false on Mac, explicitly set for Win & Linux
      toolbar: false
      resizable: false

    # The SPEC_WINDOW gets passed its own bootstrapScript
    coreWinOpts[WindowManager.SPEC_WINDOW] =
      windowKey: WindowManager.SPEC_WINDOW
      windowType: WindowManager.SPEC_WINDOW
      frame: true,
      hidden: true,
      isSpec: true,
      devMode: true,
      toolbar: false

    defaultOptions = coreWinOpts[winId] ? {}

    return Object.assign({}, defaultOptions, extraOpts)

module.exports = WindowManager
