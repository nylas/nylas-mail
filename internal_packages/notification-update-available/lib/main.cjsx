remote = require 'remote'
{Actions} = require 'inbox-exports'
ipc = require('ipc')

module.exports =

  activate: (@state) ->
    # Populate our initial state directly from the auto update manager.
    updater = remote.getGlobal('atomApplication').autoUpdateManager
    @_unlisten = Actions.notificationActionTaken.listen(@_onNotificationActionTaken, @)

    if updater.getState() is 'update-available'
      @displayNotification(updater.releaseVersion)

    # Watch for state changes via a command the auto-update manager fires.
    # This is necessary because binding callbacks through `remote` is dangerous
    @_command = atom.commands.add 'atom-workspace', 'window:update-available', (event, version, releaseNotes) =>
      @displayNotification(version)

  displayNotification: (version) ->
    version = if version then "(#{version})" else ''
    Actions.postNotification
      type: 'success',
      sticky: true
      message: "An update to Edgehill is available #{version} - Restart now to update!",
      icon: 'fa-flag',
      actions: [{
        label: 'Install'
        id: 'release-bar:install-update'
      }]

  deactivate: ->
    @_command.dispose()
    @_unlisten()

  _onNotificationActionTaken: ({notification, action}) ->
    if action.id is 'release-bar:install-update'
      ipc.send 'command', 'application:install-update'
      true