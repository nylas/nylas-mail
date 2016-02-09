autoUpdater = null
_ = require 'underscore'
{EventEmitter} = require 'events'
uuid = require 'node-uuid'
path = require 'path'
fs = require 'fs'

IdleState = 'idle'
CheckingState = 'checking'
DownloadingState = 'downloading'
UpdateAvailableState = 'update-available'
NoUpdateAvailableState = 'no-update-available'
UnsupportedState = 'unsupported'
ErrorState = 'error'

module.exports =
class AutoUpdateManager
  _.extend @prototype, EventEmitter.prototype

  constructor: (@version, @config, @specMode) ->
    @state = IdleState

    updaterId = @config.get("updateIdentity")
    if not updaterId
      updaterId = uuid.v4()
      @config.set("updateIdentity", updaterId)

    emails = []
    accounts = @config.get('nylas.accounts') || []
    for account in accounts
      if account.email_address?
        emails.push(encodeURIComponent(account.email_address))
    updaterEmails = emails.join(',')

    if process.platform is 'win32'
      # Squirrel for Windows can't handle query params
      # https://github.com/Squirrel/Squirrel.Windows/issues/132
      @feedURL = "https://edgehill.nylas.com/update-check/win32/#{process.arch}/#{@version}/#{updaterId}/#{updaterEmails}"
    else
      @feedURL = "https://edgehill.nylas.com/update-check?platform=#{process.platform}&arch=#{process.arch}&version=#{@version}&id=#{updaterId}&emails=#{updaterEmails}"

    if not @specMode
      process.nextTick => @setupAutoUpdater()

  setupAutoUpdater: ->
    if process.platform is 'win32'
      autoUpdater = require './windows-updater-squirrel-adapter'
    else
      autoUpdater = require('electron').autoUpdater

    autoUpdater.on 'error', (event, message) =>
      console.error "Error Downloading Update: #{message}"
      @setState(ErrorState)

    autoUpdater.setFeedURL(@feedURL)

    autoUpdater.on 'checking-for-update', =>
      @setState(CheckingState)

    autoUpdater.on 'update-not-available', =>
      @setState(NoUpdateAvailableState)

    autoUpdater.on 'update-available', =>
      @setState(DownloadingState)

    autoUpdater.on 'update-downloaded', (event, @releaseNotes, @releaseVersion) =>
      @setState(UpdateAvailableState)
      @emitUpdateAvailableEvent(@getWindows()...)

    @check(hidePopups: true)
    setInterval =>
      if @state in [UpdateAvailableState, UnsupportedState]
        console.log "Skipping update check... update ready to install, or updater unavailable."
        return
      @check(hidePopups: true)
    , (1000 * 60 * 30)

    switch process.platform
      when 'win32'
        @setState(UnsupportedState) unless autoUpdater.supportsUpdates()
      when 'linux'
        @setState(UnsupportedState)

  emitUpdateAvailableEvent: (windows...) ->
    return unless @releaseVersion
    for nylasWindow in windows
      nylasWindow.sendMessage('update-available', {@releaseVersion, @releaseNotes})

  setState: (state) ->
    return if @state is state
    @state = state
    @emit 'state-changed', @state

  getState: ->
    @state

  check: ({hidePopups}={}) ->
    unless hidePopups
      autoUpdater.once 'update-not-available', @onUpdateNotAvailable
      autoUpdater.once 'error', @onUpdateError

    if process.platform is "win32"
      # There's no separate "checking" stage on Windows. It also
      # "installs" as soon as it downloads. You just need to restart to
      # launch the updated app.
      autoUpdater.downloadAndInstallUpdate()
    else
      autoUpdater.checkForUpdates()

  install: ->
    if process.platform is "win32"
      # On windows the update has already been "installed" and shortcuts
      # already updated. You just need to restart the app to load the new
      # version.
      autoUpdater.restartN1()
    else
      autoUpdater.quitAndInstall()

  iconURL: ->
    url = path.join(process.resourcesPath, 'app', 'nylas.png')
    return undefined unless fs.existsSync(url)
    url

  onUpdateNotAvailable: =>
    autoUpdater.removeListener 'error', @onUpdateError
    {dialog} = require 'electron'
    dialog.showMessageBox
      type: 'info'
      buttons: ['OK']
      icon: @iconURL()
      message: 'No update available.'
      title: 'No Update Available'
      detail: "You're running the latest version of N1 (#{@version})."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    {dialog} = require 'electron'
    dialog.showMessageBox
      type: 'warning'
      buttons: ['OK']
      icon: @iconURL()
      message: 'There was an error checking for updates.'
      title: 'Update Error'
      detail: message

  getWindows: ->
    global.application.windowManager.windows()
