{ComponentRegistry,
 PreferencesUIStore,
 WorkspaceStore} = require 'nylas-exports'

module.exports =

  activate: (@state={}) ->
    @preferencesTab = new PreferencesUIStore.TabItem
      tabId: "Plugins"
      displayName: "Plugins"
      component: require "./preferences-plugins"

    PreferencesUIStore.registerPreferencesTab(@preferencesTab)

  deactivate: ->
    PreferencesUIStore.unregisterPreferencesTab(@preferencesTab.sectionId)
