SystemTrayManager = require './system-tray-manager'
NylasWindow = require './nylas-window'
WindowManager = require './window-manager'
ApplicationMenu = require './application-menu'
AutoUpdateManager = require './auto-update-manager'
NylasProtocolHandler = require './nylas-protocol-handler'
SharedFileManager = require './shared-file-manager'

{BrowserWindow, Menu, app, ipcMain, dialog} = require 'electron'

_ = require 'underscore'
fs = require 'fs-plus'
os = require 'os'
net = require 'net'
url = require 'url'
exec = require('child_process').exec
path = require 'path'
querystring = require 'querystring'
{EventEmitter} = require 'events'

socketPath =
  if process.platform is 'win32'
    '\\\\.\\pipe\\edgehill-sock'
  else
    path.join(os.tmpdir(), 'edgehill.sock')

# The application's singleton class.
#
# It's the entry point into the N1 application and maintains the global state
# of the application.
#
module.exports =
class Application
  _.extend @prototype, EventEmitter.prototype

  # Public: The entry point into the N1 application.
  @open: (options) ->
    createApplication = -> new Application(options)

    # FIXME: Sometimes when socketPath doesn't exist, net.connect would strangely
    # take a few seconds to trigger 'error' event, it could be a bug of node
    # or electron, before it's fixed we check the existence of socketPath to
    # speedup startup.
    if (process.platform isnt 'win32' and not fs.existsSync socketPath) or options.specMode
      createApplication()
      return

    client = net.connect {path: socketPath}, ->
      client.write JSON.stringify(options), ->
        client.end()
        app.quit()

    client.on 'error', createApplication

  windowManager: null
  applicationMenu: null
  nylasProtocolHandler: null
  resourcePath: null
  version: null
  systemTrayManager: null

  exit: (status) -> app.exit(status)

  constructor: (options) ->
    {@resourcePath, @configDirPath, @version, @devMode, @specMode, @safeMode} = options

    # Normalize to make sure drive letter case is consistent on Windows
    @resourcePath = path.normalize(@resourcePath) if @resourcePath

    global.application = this

    @sharedFileManager = new SharedFileManager()
    @nylasProtocolHandler = new NylasProtocolHandler(@resourcePath, @safeMode)

    Config = require '../config'
    @config = new Config({@configDirPath, @resourcePath})
    @config.load()

    if not @config.get('core.disabledPackagesInitialized')
      exampleNewNames = {
        'N1-Scheduler': 'N1-Scheduler',
        'N1-Composer-Templates': 'composer-templates',
        'N1-Composer-Translate': 'composer-translate',
        'N1-Message-View-on-Github':'message-view-on-github',
        'N1-Personal-Level-Indicators':'personal-level-indicators',
        'N1-Phishing-Detection': 'phishing-detection',
        'N1-Github-Contact-Card-Section': 'github-contact-card',
      }
      exampleOldNames = Object.keys(exampleNewNames)
      examplesEnabled = []

      if fs.existsSync(path.join(@configDirPath, 'packages'))
        # Temporary: Find the examples that have been manually installed
        packages = fs.readdirSync(path.join(@configDirPath, 'packages'))
        examplesEnabled = packages.filter (packageName) ->
          packageName in exampleOldNames and packageName[0] isnt '.'

        # Move old installed examples to a deprecated folder
        deprecatedPath = path.join(@configDirPath, 'packages-deprecated')
        fs.mkdirSync(deprecatedPath) unless fs.existsSync(deprecatedPath)
        examplesEnabled.forEach (dir) =>
          prevPath = path.join(@configDirPath, 'packages', dir)
          nextPath = path.join(deprecatedPath, dir)
          fs.renameSync(prevPath, nextPath)

      # Disable examples not specifically enabled
      for oldName, newName of exampleNewNames
        continue if oldName in examplesEnabled
        @config.pushAtKeyPath('core.disabledPackages', newName)
      @config.set('core.disabledPackagesInitialized', true)

    # Normally, you enter dev mode by passing the --dev command line flag.
    # But for developers using the compiled app, it's easier to toggle dev
    # mode from the menu and have it persist through relaunch.
    if @config.get('devMode')
      @devMode = true

    initializeInBackground = options.background ? false
    @windowManager = new WindowManager({@resourcePath, @configDirPath, @config, @devMode, @safeMode, initializeInBackground})
    @autoUpdateManager = new AutoUpdateManager(@version, @config, @specMode)
    @applicationMenu = new ApplicationMenu(@version)
    @_databasePhase = 'setup'

    @systemTrayManager = new SystemTrayManager(process.platform, @)

    @listenForArgumentsFromNewProcess()
    @setupJavaScriptArguments()
    @handleEvents()

    @launchWithOptions(options)

  getMainNylasWindow: ->
    @windowManager.mainWindow()

  getMainWindow: ->
    @getMainNylasWindow().browserWindow

  # Opens a new window based on the options provided.
  launchWithOptions: ({urlsToOpen, pathsToOpen, specMode, safeMode, specDirectory, specFilePattern, logFile, showSpecsInWindow}) ->
    if specMode
      exitWhenDone = true
      @runSpecs({exitWhenDone, showSpecsInWindow, @resourcePath, specDirectory, specFilePattern, logFile})
    else
      @openWindowsForTokenState()
      if pathsToOpen instanceof Array
        @openComposerWithFiles(pathsToOpen)
      if urlsToOpen instanceof Array
        @openUrl(urlToOpen) for urlToOpen in urlsToOpen

  # Creates server to listen for additional N1 application launches.
  #
  # You can run the N1 command multiple times, but after the first launch
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

  # On Windows, removing a file can fail if a process still has it open. When
  # we close windows and log out, we need to wait for these processes to completely
  # exit and then delete the file. It's hard to tell when this happens, so we just
  # retry the deletion a few times.
  deleteFileWithRetry: (filePath, callback, retries = 5) ->
    callback ?= ->
    callbackWithRetry = (err) =>
      if err and err.message.indexOf('no such file') is -1
        console.log("File Error: #{err.message} - retrying in 150msec")
        setTimeout =>
          @deleteFileWithRetry(filePath, callback, retries - 1)
        , 150
      else
        callback(null)

    if not fs.existsSync(filePath)
      return callback(null)

    if retries > 0
      fs.unlink(filePath, callbackWithRetry)
    else
      fs.unlink(filePath, callback)

  # Configures required javascript environment flags.
  setupJavaScriptArguments: ->
    app.commandLine.appendSwitch 'js-flags', '--harmony'

  openWindowsForTokenState: (loadingMessage) =>
    hasAccount = @config.get('nylas.accounts')?.length > 0
    if hasAccount
      @windowManager.showMainWindow(loadingMessage)
      @windowManager.ensureWorkWindow()
    else
      @windowManager.ensureOnboardingWindow(welcome: true)
      # The onboarding window automatically shows when it's ready

  _resetConfigAndRelaunch: =>
    @setDatabasePhase('close')
    @windowManager.closeAllWindows()
    @_deleteDatabase =>
      @config.set('nylas', null)
      @config.set('edgehill', null)
      @setDatabasePhase('setup')
      @windowManager.ensureOnboardingWindow(welcome: true)

  _deleteDatabase: (callback) ->
    @deleteFileWithRetry path.join(@configDirPath,'edgehill.db'), callback
    @deleteFileWithRetry path.join(@configDirPath,'edgehill.db-wal')
    @deleteFileWithRetry path.join(@configDirPath,'edgehill.db-shm')

  databasePhase: ->
    @_databasePhase

  setDatabasePhase: (phase) ->
    unless phase in ['setup', 'ready', 'close']
      throw new Error("setDatabasePhase: #{phase} is invalid.")

    return if phase is @_databasePhase

    @_databasePhase = phase
    @windowManager.windows().forEach (nylasWindow) ->
      return unless nylasWindow.browserWindow.webContents
      nylasWindow.browserWindow.webContents.send('database-phase-change', phase)

  rebuildDatabase: =>
    return if @_databasePhase is 'close'
    @setDatabasePhase('close')
    @windowManager.closeAllWindows()

    loadingMessage = "Please wait while we prepare new features."
    @_deleteDatabase =>
      @setDatabasePhase('setup')
      @openWindowsForTokenState(loadingMessage)

  # Registers basic application commands, non-idempotent.
  # Note: If these events are triggered while an application window is open, the window
  # needs to manually bubble them up to the Application instance via IPC or they won't be
  # handled. This happens in workspace-element.coffee
  handleEvents: ->
    @on 'application:run-all-specs', ->
      @runSpecs
        exitWhenDone: false
        showSpecsInWindow: true
        resourcePath: @resourcePath
        safeMode: @windowManager.focusedWindow()?.safeMode

    @on 'application:run-package-specs', ->
      dialog.showOpenDialog {
        title: 'Choose a Package Directory'
        defaultPath: @configDirPath,
        properties: ['openDirectory']
      }, (filenames) =>
        return if not filenames or filenames.length is 0
        @runSpecs
          exitWhenDone: false
          showSpecsInWindow: true
          resourcePath: @resourcePath
          specDirectory: filenames[0]

    @on 'application:reset-config-and-relaunch', @_resetConfigAndRelaunch

    @on 'application:quit', => app.quit()
    @on 'application:inspect', ({x,y, nylasWindow}) ->
      nylasWindow ?= @windowManager.focusedWindow()
      nylasWindow?.browserWindow.inspectElement(x, y)

    @on 'application:add-account', (provider) =>
      @windowManager.ensureOnboardingWindow({provider})
    @on 'application:new-message', => @windowManager.sendToMainWindow('new-message')
    @on 'application:view-help', =>
      url = 'https://nylas.zendesk.com/hc/en-us/sections/203638587-N1'
      require('electron').shell.openExternal(url)
    @on 'application:open-preferences', => @windowManager.sendToMainWindow('open-preferences')
    @on 'application:show-main-window', => @openWindowsForTokenState()
    @on 'application:show-work-window', => @windowManager.showWorkWindow()
    @on 'application:check-for-update', => @autoUpdateManager.check()
    @on 'application:install-update', =>
      @quitting = true
      @windowManager.unregisterAllHotWindows()
      @autoUpdateManager.install()

    @on 'application:toggle-dev', =>
      @devMode = !@devMode

      if @devMode
        @config.set('devMode', true)
      else
        @config.set('devMode', undefined)

      @windowManager.closeAllWindows()
      @windowManager.devMode = @devMode
      @openWindowsForTokenState()

    @on 'application:toggle-theme', =>
      themes = @config.get('core.themes') ? []
      if 'ui-dark' in themes
        themes = _.without themes, 'ui-dark'
      else
        themes.push('ui-dark')
      @config.set('core.themes', themes)

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
      # Allow the main window to be closed.
      @quitting = true
      # Destroy hot windows so that they can't block the app from quitting.
      # (Electron will wait for them to finish loading before quitting.)
      @windowManager.unregisterAllHotWindows()
      @systemTrayManager?.destroy()

    # Called after the app has closed all windows.
    app.on 'will-quit', =>
      @setDatabasePhase('close')
      @deleteSocketFile()

    app.on 'will-exit', =>
      @setDatabasePhase('close')
      @deleteSocketFile()

    app.on 'open-file', (event, pathToOpen) =>
      @openComposerWithFiles([pathToOpen])
      event.preventDefault()

    app.on 'open-url', (event, urlToOpen) =>
      @openUrl(urlToOpen)
      event.preventDefault()

    # System Tray
    ipcMain.on 'update-system-tray', (event, args...) =>
      @systemTrayManager?.updateTray(args...)

    ipcMain.on 'set-badge-value', (event, value) =>
      app.dock?.setBadge?(value)

    ipcMain.on 'new-window', (event, options) =>
      @windowManager.newWindow(options)

    ipcMain.on 'register-hot-window', (event, options) =>
      @windowManager.registerHotWindow(options)

    ipcMain.on 'unregister-hot-window', (event, windowType) =>
      @windowManager.unregisterHotWindow(windowType)

    ipcMain.on 'from-react-remote-window', (event, json) =>
      @windowManager.sendToMainWindow('from-react-remote-window', json)

    ipcMain.on 'from-react-remote-window-selection', (event, json) =>
      @windowManager.sendToMainWindow('from-react-remote-window-selection', json)

    ipcMain.on 'inline-style-parse', (event, {html, key}) =>
      juice = require 'juice'
      try
        html = juice(html)
      catch
        # If the juicer fails (because of malformed CSS or some other
        # reason), then just return the body. We will still push it
        # through the HTML sanitizer which will strip the style tags. Oh
        # well.
        html = html
      # win = BrowserWindow.fromWebContents(event.sender)
      event.sender.send('inline-styles-result', {html, key})

    app.on 'activate', (event, hasVisibleWindows) =>
      if not hasVisibleWindows
        @openWindowsForTokenState()
      event.preventDefault()

    ipcMain.on 'update-application-menu', (event, template, keystrokesByCommand) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @applicationMenu.update(win, template, keystrokesByCommand)

    ipcMain.on 'command', (event, command, args...) =>
      @emit(command, args...)

    ipcMain.on 'window-command', (event, command, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      win.emit(command, args...)

    ipcMain.on 'call-window-method', (event, method, args...) ->
      win = BrowserWindow.fromWebContents(event.sender)
      console.error("Method #{method} does not exist on BrowserWindow!") unless win[method]
      win[method](args...)

    ipcMain.on 'call-devtools-webcontents-method', (event, method, args...) ->
      # If devtools aren't open the `webContents::devToolsWebContents` will be null
      event.sender.devToolsWebContents?[method](args...)

    ipcMain.on 'call-webcontents-method', (event, method, args...) ->
      console.error("Method #{method} does not exist on WebContents!") unless event.sender[method]
      event.sender[method](args...)

    ipcMain.on 'action-bridge-rebroadcast-to-all', (event, args...) =>
      win = BrowserWindow.fromWebContents(event.sender)
      @windowManager.windows().forEach (nylasWindow) ->
        return if nylasWindow.browserWindow == win
        return unless nylasWindow.browserWindow.webContents
        nylasWindow.browserWindow.webContents.send('action-bridge-message', args...)

    ipcMain.on 'action-bridge-rebroadcast-to-work', (event, args...) =>
      workWindow = @windowManager.workWindow()
      return if not workWindow or not workWindow.browserWindow.webContents
      return if BrowserWindow.fromWebContents(event.sender) is workWindow
      workWindow.browserWindow.webContents.send('action-bridge-message', args...)

    clipboard = null
    ipcMain.on 'write-text-to-selection-clipboard', (event, selectedText) ->
      clipboard ?= require('electron').clipboard
      clipboard.writeText(selectedText, 'selection')

    ipcMain.on 'account-setup-successful', (event) =>
      @windowManager.showMainWindow()
      @windowManager.ensureWorkWindow()
      @windowManager.onboardingWindow()?.close()

    ipcMain.on 'new-account-added', (event) =>
      @windowManager.ensureWorkWindow()

    ipcMain.on 'run-in-window', (event, params) =>
      @_sourceWindows ?= {}
      sourceWindow = BrowserWindow.fromWebContents(event.sender)
      @_sourceWindows[params.taskId] = sourceWindow
      if params.window is "work"
        targetWindow = @windowManager.workWindow()
      else if params.window is "main"
        targetWindow = @windowManager.mainWindow()
      else throw new Error("We don't support running in that window")
      return if not targetWindow or not targetWindow.browserWindow.webContents
      targetWindow.browserWindow.webContents.send('run-in-window', params)

    ipcMain.on 'remote-run-results', (event, params) =>
      sourceWindow = @_sourceWindows[params.taskId]
      sourceWindow.webContents.send('remote-run-results', params)
      delete @_sourceWindows[params.taskId]

  # Public: Executes the given command.
  #
  # If it isn't handled globally, delegate to the currently focused window.
  # If there is no focused window (all the windows of the app are hidden),
  # fire the command to the main window. (This ensures that `application:`
  # commands, like Cmd-N work when no windows are visible.)
  #
  # command - The string representing the command.
  # args - The optional arguments to pass along.
  sendCommand: (command, args...) ->
    unless @emit(command, args...)
      focusedWindow = @windowManager.focusedWindow()
      if focusedWindow
        focusedWindow.sendCommand(command, args...)
      else
        unless @sendCommandToFirstResponder(command)
          focusedBrowserWindow = BrowserWindow.getFocusedWindow()
          mainWindow = @windowManager.mainWindow()
          if focusedBrowserWindow
            switch command
              when 'window:reload' then focusedBrowserWindow.reload()
              when 'window:toggle-dev-tools' then focusedBrowserWindow.toggleDevTools()
              when 'window:close' then focusedBrowserWindow.close()
          else if mainWindow
            mainWindow.sendCommand(command, args...)

  # Public: Executes the given command on the given window.
  #
  # command - The string representing the command.
  # nylasWindow - The {NylasWindow} to send the command to.
  # args - The optional arguments to pass along.
  sendCommandToWindow: (command, nylasWindow, args...) ->
    unless @emit(command, args...)
      if nylasWindow?
        nylasWindow.sendCommand(command, args...)
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

  openComposerWithFiles: (pathsToOpen) ->
    @windowManager.sendToMainWindow('mailfiles', pathsToOpen)

  # Opens up a new {NylasWindow} to run specs within.
  #
  # options -
  #   :exitWhenDone - A Boolean that, if true, will close the window upon
  #                   completion and exit the app with the status code of
  #                   1 if the specs failed and 0 if they passed.
  #   :showSpecsInWindow - A Boolean that, if true, will run specs in a
  #                        window
  #   :resourcePath - The path to include specs from.
  #   :specPath - The directory to load specs from.
  #   :safeMode - A Boolean that, if true, won't run specs from ~/.nylas/packages
  #               and ~/.nylas/dev/packages, defaults to false.
  runSpecs: ({exitWhenDone, showSpecsInWindow, resourcePath, specDirectory, specFilePattern, logFile, safeMode}) ->
    if resourcePath isnt @resourcePath and not fs.existsSync(resourcePath)
      resourcePath = @resourcePath

    try
      bootstrapScript = require.resolve(path.resolve(@resourcePath, 'spec', 'spec-bootstrap'))
    catch error
      bootstrapScript = require.resolve(path.resolve(__dirname, '..', '..', 'spec', 'spec-bootstrap'))

    isSpec = true
    devMode = true
    safeMode ?= false

    # Important: Use .nylas-spec instead of .nylas to avoid overwriting the
    # user's real email config!
    configDirPath = path.join(app.getPath('home'), '.nylas-spec')

    new NylasWindow({bootstrapScript, configDirPath, resourcePath, exitWhenDone, isSpec, devMode, specDirectory, specFilePattern, logFile, safeMode, showSpecsInWindow})
