remote = require 'remote'
{Actions} = require 'nylas-exports'
ipc = require('ipc')

module.exports =

  activate: (@state) ->
    # Populate our initial state directly from the auto update manager.
    updater = remote.getGlobal('application').autoUpdateManager
    @_unlisten = Actions.notificationActionTaken.listen(@_onNotificationActionTaken, @)

    configVersion = atom.config.get("lastVersion")
    currentVersion = atom.getVersion()
    if configVersion and configVersion isnt currentVersion
      atom.config.set("lastVersion", currentVersion)
      @displayThanksNotification()

    if updater.getState() is 'update-available'
      @displayNotification(updater.releaseVersion)

    atom.onUpdateAvailable ({releaseVersion, releaseNotes} = {}) =>
      @displayNotification(releaseVersion)

  displayThanksNotification: ->
    Actions.postNotification
      type: 'info'
      tag: 'app-update'
      sticky: true
      message: "You're running the latest version of N1 - view the changelog to see what's new.",
      icon: 'fa-magic'
      actions: [{
        dismisses: true
        label: 'Thanks'
        id: 'release-bar:no-op'
      },{
        default: true
        dismisses: true
        label: 'See What\'s New'
        id: 'release-bar:view-changelog'
      }]

  displayNotification: (version) ->
    version = if version then "(#{version})" else ''
    Actions.postNotification
      type: 'info'
      tag: 'app-update'
      sticky: true
      message: "An update to N1 is available #{version} - click to update now!",
      icon: 'fa-flag'
      actions: [{
        label: 'See What\'s New'
        id: 'release-bar:view-changelog'
      },{
        label: 'Install Now'
        dismisses: true
        default: true
        id: 'release-bar:install-update'
      }]

  deactivate: ->
    @_unlisten()

  _onNotificationActionTaken: ({notification, action}) ->
    if action.id is 'release-bar:install-update'
      ipc.send 'command', 'application:install-update'
      true
    if action.id is 'release-bar:view-changelog'
      require('shell').openExternal('https://github.com/nylas/N1/blob/master/CHANGELOG.md')
      false
