{BrowserWindow, app, dialog} = require 'electron'
path = require 'path'
fs = require 'fs'
url = require 'url'
_ = require 'underscore'
{EventEmitter} = require 'events'

WindowIconPath = null
idNum = 0

module.exports =
class MailspringWindow
  _.extend @prototype, EventEmitter.prototype

  @includeShellLoadTime: true

  browserWindow: null
  loaded: null
  isSpec: null

  constructor: (settings={}) ->
    {frame,
     title,
     width,
     height,
     toolbar,
     resizable,
     pathToOpen,
     @isSpec,
     @devMode,
     @windowKey,
     @safeMode,
     @neverClose,
     @mainWindow,
     @windowType,
     @resourcePath,
     @exitWhenDone,
     @configDirPath} = settings

    if !@windowKey
      @windowKey = "#{@windowType}-#{idNum}"
      idNum += 1

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    browserWindowOptions =
      show: false
      title: title ? 'Mailspring'
      frame: frame
      width: width
      height: height
      resizable: resizable
      webPreferences:
        directWrite: true
      autoHideMenuBar: false

    if @neverClose
      # Prevents DOM timers from being suspended when the main window is hidden.
      # Means there's not an awkward catch-up when you re-show the main window.
      # TODO
      # This option is no longer working according to
      # https://github.com/atom/electron/issues/3225
      # Look into using option --disable-renderer-backgrounding
      browserWindowOptions.webPreferences.pageVisibility = true

    # Don't set icon on Windows so the exe's ico will be used as window and
    # taskbar's icon. See https://github.com/atom/atom/issues/4811 for more.
    if process.platform is 'linux'
      unless WindowIconPath
        WindowIconPath = path.resolve(__dirname, '..', '..', 'mailspring.png')
        unless fs.existsSync(WindowIconPath)
          WindowIconPath = path.resolve(__dirname, '..', '..', 'build', 'resources', 'mailspring.png')
      browserWindowOptions.icon = WindowIconPath

    @browserWindow = new BrowserWindow(browserWindowOptions)
    @browserWindow.updateLoadSettings = @updateLoadSettings

    @handleEvents()

    loadSettings = Object.assign({}, settings)
    loadSettings.windowState ?= '{}'
    loadSettings.appVersion = global.application.version
    loadSettings.resourcePath = @resourcePath
    loadSettings.devMode ?= false
    loadSettings.safeMode ?= false
    loadSettings.mainWindow ?= @mainWindow
    loadSettings.windowType ?= "default"

    # Only send to the first non-spec window created
    if @constructor.includeShellLoadTime and not @isSpec
      @constructor.includeShellLoadTime = false
      loadSettings.shellLoadTime ?= Date.now() - global.shellStartTime

    loadSettings.initialPath = pathToOpen
    if fs.statSyncNoException(pathToOpen).isFile?()
      loadSettings.initialPath = path.dirname(pathToOpen)

    @browserWindow.loadSettings = loadSettings

    @browserWindow.once 'window:loaded', =>
      @loaded = true
      if @browserWindow.loadSettingsChangedSinceGetURL
        @browserWindow.webContents.send('load-settings-changed', @browserWindow.loadSettings)
      @emit 'window:loaded'

    @browserWindow.loadURL(@getURL(loadSettings))
    @browserWindow.focusOnWebView() if @isSpec

  updateLoadSettings: (newSettings={}) =>
    @loaded = true
    @setLoadSettings(Object.assign({}, @browserWindow.loadSettings, newSettings))

  loadSettings: ->
    @browserWindow.loadSettings

  # This gets called when we want to turn a WindowLauncher.EMPTY_WINDOW
  # into a new kind of custom popout window.
  #
  # The windowType will change which will cause a new set of plugins to
  # load.
  setLoadSettings: (loadSettings) ->
    @browserWindow.loadSettings = loadSettings
    @browserWindow.loadSettingsChangedSinceGetURL = true
    @browserWindow.webContents.send('load-settings-changed', loadSettings)

  getURL: (loadSettingsObj) ->
    # Ignore the windowState when passing loadSettings via URL, since it could
    # be quite large.
    loadSettings = _.clone(loadSettingsObj)
    delete loadSettings['windowState']

    @browserWindow.loadSettingsChangedSinceGetURL = false

    url.format
      protocol: 'file'
      pathname: "#{@resourcePath}/static/index.html"
      slashes: true
      query: {loadSettings: JSON.stringify(loadSettings)}

  handleEvents: ->
    # Also see logic in `AppEnv::onBeforeUnload` and
    # `WindowEventHandler::AddUnloadCallback`. Classes like the DraftStore
    # and ActionBridge intercept the closing of windows and perform
    # action.
    #
    # This uses the DOM's `beforeunload` event.
    @browserWindow.on 'close', (event) =>
      if @neverClose and !global.application.isQuitting()
        # For neverClose windows (like the main window) simply hide and
        # take out of full screen.
        event.preventDefault()
        if @browserWindow.isFullScreen()
          @browserWindow.once 'leave-full-screen', =>
            @browserWindow.hide()
          @browserWindow.setFullScreen(false)
        else
          @browserWindow.hide()

        # HOWEVER! If the neverClose window is the last window open, and
        # it looks like there's no windows actually quit the application
        # on Linux & Windows.
        if not @isSpec
          global.application.windowManager.quitWinLinuxIfNoWindows()

    @browserWindow.on 'scroll-touch-begin', =>
      @browserWindow.webContents.send('scroll-touch-begin')

    @browserWindow.on 'scroll-touch-end', =>
      @browserWindow.webContents.send('scroll-touch-end')

    @browserWindow.on 'focus', =>
      @browserWindow.webContents.send('browser-window-focus')

    @browserWindow.on 'blur', =>
      @browserWindow.webContents.send('browser-window-blur')

    @browserWindow.webContents.on 'will-navigate', (event, url) =>
      event.preventDefault()

    @browserWindow.webContents.on 'new-window', (event, url, frameName, disposition) =>
      event.preventDefault()

    @browserWindow.on 'unresponsive', =>
      return if @isSpec
      return if not @loaded

      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'Mailspring is not responding'
        detail: 'Would you like to force close it or keep waiting?'
      @browserWindow.destroy() if chosen is 0

    @browserWindow.webContents.on 'crashed', (event, killed) =>
      if killed
        # Killed means that the app is exiting and the browser window is being
        # forceably cleaned up. Carry on, do not try to reload the window.
        @browserWindow.destroy()
        return

      app.exit(100) if @exitWhenDone

      if @neverClose
        @browserWindow.reload()
      else
        chosen = dialog.showMessageBox @browserWindow,
          type: 'warning'
          buttons: ['Close Window', 'Reload', 'Keep It Open']
          message: 'Mailspring has crashed'
          detail: 'Please report this issue to us at support@getmailspring.com.'
        switch chosen
          when 0 then @browserWindow.destroy()
          when 1 then @browserWindow.reload()

    if @isSpec
      # Workaround for https://github.com/atom/electron/issues/380
      # Don't focus the window when it is being blurred during close or
      # else the app will crash on Windows.
      if process.platform is 'win32'
        @browserWindow.on 'close', => @isWindowClosing = true

      # Spec window's web view should always have focus
      @browserWindow.on 'blur', =>
        @browserWindow.focusOnWebView() unless @isWindowClosing

  sendMessage: (message, detail) ->
    @waitForLoad =>
      @browserWindow.webContents.send(message, detail)

  sendCommand: (command, args...) ->
    if @isSpecWindow()
      unless global.application.sendCommandToFirstResponder(command)
        switch command
          when 'window:reload' then @reload()
          when 'window:toggle-dev-tools' then @toggleDevTools()
          when 'window:close' then @close()
    else if @isWebViewFocused()
      @sendCommandToBrowserWindow(command, args...)
    else
      unless global.application.sendCommandToFirstResponder(command)
        @sendCommandToBrowserWindow(command, args...)

  sendCommandToBrowserWindow: (command, args...) ->
    @browserWindow.webContents.send 'command', command, args...

  getDimensions: ->
    [x, y] = @browserWindow.getPosition()
    [width, height] = @browserWindow.getSize()
    {x, y, width, height}

  close: -> @browserWindow.close()

  hide: -> @browserWindow.hide()

  show: -> @browserWindow.show()

  showWhenLoaded: ->
    @waitForLoad =>
      @show()
      @focus()

  waitForLoad: (fn) ->
    if @loaded
      fn()
    else
      @once('window:loaded', fn)

  focus: -> @browserWindow.focus()

  minimize: -> @browserWindow.minimize()

  maximize: -> @browserWindow.maximize()

  restore: -> @browserWindow.restore()

  isFocused: -> @browserWindow.isFocused()

  isMinimized: -> @browserWindow.isMinimized()

  isVisible: -> @browserWindow.isVisible()

  isLoaded: -> @loaded

  isWebViewFocused: -> @browserWindow.isWebViewFocused()

  isSpecWindow: -> @isSpec

  reload: -> @browserWindow.reload()

  toggleDevTools: -> @browserWindow.toggleDevTools()
