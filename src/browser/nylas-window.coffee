{BrowserWindow, app} = require 'electron'
path = require 'path'
fs = require 'fs'
url = require 'url'
_ = require 'underscore'
{EventEmitter} = require 'events'

WindowIconPath = null

module.exports =
class NylasWindow
  _.extend @prototype, EventEmitter.prototype

  @includeShellLoadTime: true

  browserWindow: null
  loaded: null
  isSpec: null

  constructor: (settings={}) ->
    {title,
     width,
     height,
     toolbar,
     resizable,
     pathToOpen,
     showSpecsInWindow,
     @isSpec,
     @devMode,
     @safeMode,
     @neverClose,
     @mainWindow,
     @resourcePath,
     @exitWhenDone,
     @configDirPath} = settings

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    # Mac: We'll render a CSS toolbar if `toolbar=true`. No frame required.
    # Win / Linux: We don't render a toolbar in CSS - include frame if the
    # window requests a toolbar. Remove this code once we have custom toolbars
    # on win/linux.

    toolbar ?= true
    if process.platform is 'darwin'
      frame = false
    else
      frame = toolbar

    if @isSpec
      frame = true
      toolbar = false

    options =
      show: false
      title: title ? 'Nylas N1'
      frame: frame
      width: width
      height: height
      resizable: resizable ? true
      webPreferences:
        directWrite: true

    if @neverClose
      # Prevents DOM timers from being suspended when the main window is hidden.
      # Means there's not an awkward catch-up when you re-show the main window.
      # TODO
      # This option is no longer working according to
      # https://github.com/atom/electron/issues/3225
      # Look into using option --disable-renderer-backgrounding
      options.webPreferences.pageVisibility = true

    # Don't set icon on Windows so the exe's ico will be used as window and
    # taskbar's icon. See https://github.com/atom/atom/issues/4811 for more.
    if process.platform is 'linux'
      unless WindowIconPath
        WindowIconPath = path.resolve(__dirname, '..', '..', 'nylas.png')
        unless fs.existsSync(WindowIconPath)
          WindowIconPath = path.resolve(__dirname, '..', '..', 'build', 'resources', 'nylas.png')
      options.icon = WindowIconPath

    @browserWindow = new BrowserWindow(options)
    global.application.windowManager.addWindow(this)

    @handleEvents()

    loadSettings = _.extend({}, settings)
    loadSettings.toolbar = toolbar
    loadSettings.windowState ?= '{}'
    loadSettings.appVersion = app.getVersion()
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

    @setLoadSettings(loadSettings)

    @browserWindow.once 'window:loaded', =>
      @emit 'window:loaded'
      @loaded = true
      if @mainWindow
        @browserWindow.setResizable(true)
      if @browserWindow.loadSettingsChangedSinceGetURL
        @browserWindow.webContents.send('load-settings-changed', @browserWindow.loadSettings)

    @browserWindow.loadURL(@getURL(loadSettings))
    @browserWindow.focusOnWebView() if @isSpec

  loadSettings: ->
    @browserWindow.loadSettings

  setLoadSettings: (loadSettings) ->
    @browserWindow.loadSettings = loadSettings
    @browserWindow.loadSettingsChangedSinceGetURL = true
    if @loaded
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

  setupContextMenu: ->
    ContextMenu = null

    @browserWindow.on 'context-menu', (menuTemplate) =>
      ContextMenu ?= require './context-menu'
      new ContextMenu(menuTemplate, this)

  handleEvents: ->
    @browserWindow.on 'close', (event) =>
      if @neverClose and !global.application.quitting
        event.preventDefault()
        if @browserWindow.isFullScreen()
          @browserWindow.once 'leave-full-screen', =>
            @browserWindow.hide()
          @browserWindow.setFullScreen(false)
        else
          @browserWindow.hide()
        @emit 'window:close-prevented'

    @browserWindow.on 'closed', =>
      global.application.windowManager.removeWindow(this)

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

      {dialog} = require 'electron'
      chosen = dialog.showMessageBox @browserWindow,
        type: 'warning'
        buttons: ['Close', 'Keep Waiting']
        message: 'N1 is not responding'
        detail: 'Would you like to force close it or keep waiting?'
      @browserWindow.destroy() if chosen is 0

    @browserWindow.webContents.on 'crashed', =>
      global.application.exit(100) if @exitWhenDone

      if @neverClose
        @browserWindow.reload()
      else
        {dialog} = require 'electron'
        chosen = dialog.showMessageBox @browserWindow,
          type: 'warning'
          buttons: ['Close Window', 'Reload', 'Keep It Open']
          message: 'N1 has crashed'
          detail: 'Please report this issue to us at support@nylas.com.'
        switch chosen
          when 0 then @browserWindow.destroy()
          when 1 then @browserWindow.reload()

    @setupContextMenu()

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
