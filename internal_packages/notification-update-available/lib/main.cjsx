remote = require 'remote'
{Actions} = require 'nylas-exports'
ipc = require('ipc')

module.exports =

  activate: (@state) ->
    # Populate our initial state directly from the auto update manager.
    updater = remote.getGlobal('application').autoUpdateManager
    @_unlisten = Actions.notificationActionTaken.listen(@_onNotificationActionTaken, @)

    if updater.getState() is 'update-available'
      @displayNotification(updater.releaseVersion)

    atom.onUpdateAvailable ({releaseVersion, releaseNotes} = {}) =>
      @displayNotification(releaseVersion)

  displayNotification: (version) ->
    version = if version then "(#{version})" else ''
    Actions.postNotification
      type: 'info',
      sticky: true
      message: "An update to Edgehill is available #{version} - Restart now to update!",
      icon: 'fa-flag',
      actions: [{
        label: 'Install'
        id: 'release-bar:install-update'
      }]

  deactivate: ->
    @_unlisten()

  _onNotificationActionTaken: ({notification, action}) ->
    if action.id is 'release-bar:install-update'
      ipc.send 'command', 'application:install-update'
      true
