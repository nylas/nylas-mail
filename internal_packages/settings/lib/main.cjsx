SettingsView = require "./settings-view"
SettingsTabsView = require "./settings-tabs-view"

{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'

module.exports =

  activate: (@state={}) ->
    WorkspaceStore.defineSheet 'Settings', {root: true, supportedModes: ['list']},
      list: ['RootSidebar', 'SettingsSidebar', 'Settings']

    ComponentRegistry.register SettingsTabsView,
      location: WorkspaceStore.Location.SettingsSidebar

    ComponentRegistry.register SettingsView,
      location: WorkspaceStore.Location.Settings

  deactivate: ->
    ComponentRegistry.unregister(SettingsView)
    ComponentRegistry.unregister(SettingsTabsView)
    WorkspaceStore.undefineSheet('Settings')
