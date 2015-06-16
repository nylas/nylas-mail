autoUpdater = null
_ = require 'underscore'
{EventEmitter} = require 'events'
path = require 'path'
fs = require 'fs'

IdleState = 'idle'
CheckingState = 'checking'
DownladingState = 'downloading'
UpdateAvailableState = 'update-available'
NoUpdateAvailableState = 'no-update-available'
UnsupportedState = 'unsupported'
ErrorState = 'error'

module.exports =
class AutoUpdateManager
  _.extend @prototype, EventEmitter.prototype

  constructor: (@version, @config, @specMode) ->
    @state = IdleState
    if process.platform is 'win32'
      # Squirrel for Windows can't handle query params
      # https://github.com/Squirrel/Squirrel.Windows/issues/132
      @feedUrl = 'https://edgehill.nylas.com/update-check'
    else
      upgradeLevel = @getUpgradeLevel()
      @feedUrl = "https://edgehill.nylas.com/update-check?version=#{@version}&level=#{upgradeLevel}"

    if not @specMode
      process.nextTick => @setupAutoUpdater()

  getUpgradeLevel: ->
    lvl = @config.get("updateLevel") ? "patch"
    if lvl not in ["major", "minor", "patch", "commit"] then lvl = "patch"
    return lvl

  setupAutoUpdater: ->
    if process.platform is 'win32'
      autoUpdater = require './auto-updater-win32'
    else
      autoUpdater = require 'auto-updater'

    autoUpdater.on 'error', (event, message) =>
      console.error "Error Downloading Update: #{message}"
      @setState(ErrorState)

    autoUpdater.setFeedUrl(@feedUrl)

    autoUpdater.on 'checking-for-update', =>
      @setState(CheckingState)

    autoUpdater.on 'update-not-available', =>
      @setState(NoUpdateAvailableState)

    autoUpdater.on 'update-available', =>
      @setState(DownladingState)

    autoUpdater.on 'update-downloaded', (event, @releaseNotes, @releaseVersion) =>
      @setState(UpdateAvailableState)
      @emitUpdateAvailableEvent(@getWindows()...)

    @check(hidePopups: true)
    setInterval =>
      @check(hidePopups: true)
    , (1000 * 60 * 5)

    switch process.platform
      when 'win32'
        @setState(UnsupportedState) unless autoUpdater.supportsUpdates()
      when 'linux'
        @setState(UnsupportedState)

  emitUpdateAvailableEvent: (windows...) ->
    return unless @releaseVersion? and @releaseNotes
    for atomWindow in windows
      atomWindow.sendMessage('update-available', {@releaseVersion, @releaseNotes})

  setState: (state) ->
    return if @state is state
    @state = state
    @emit 'state-changed', @state

  getState: ->
    @state

  check: ({hidePopups}={}) ->
    console.log "Checking for updates..."
    unless hidePopups
      autoUpdater.once 'update-not-available', @onUpdateNotAvailable
      autoUpdater.once 'error', @onUpdateError
    autoUpdater.checkForUpdates()

  install: ->
    autoUpdater.quitAndInstall()

  iconURL: ->
    url = path.join(process.resourcesPath, 'app', 'nylas.png')
    return undefined unless fs.existsSync(url)
    url

  onUpdateNotAvailable: =>
    autoUpdater.removeListener 'error', @onUpdateError
    dialog = require 'dialog'
    dialog.showMessageBox
      type: 'info'
      buttons: ['OK']
      icon: @iconURL()
      message: 'No update available.'
      title: 'No Update Available'
      detail: "You're running the latest version of Nylas Mail (#{@version})."

  onUpdateError: (event, message) =>
    autoUpdater.removeListener 'update-not-available', @onUpdateNotAvailable
    dialog = require 'dialog'
    dialog.showMessageBox
      type: 'warning'
      buttons: ['OK']
      icon: @iconURL()
      message: 'There was an error checking for updates.'
      title: 'Update Error'
      detail: message

  getWindows: ->
    global.application.windowManager.windows()
