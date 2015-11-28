{PreferencesSectionStore,
 Actions,
 WorkspaceStore,
 ComponentRegistry} = require 'nylas-exports'
{ipcRenderer} = require 'electron'

module.exports =

  activate: ->
    React = require 'react'

    Cfg = PreferencesSectionStore.SectionConfig

    PreferencesSectionStore.registerPreferenceSection(new Cfg {
      icon: 'ic-settings-general.png'
      sectionId: 'General'
      displayName: 'General'
      component: require './tabs/preferences-general'
      order: 1
    })
    PreferencesSectionStore.registerPreferenceSection(new Cfg {
      icon: 'ic-settings-accounts.png'
      sectionId: 'Accounts'
      displayName: 'Accounts'
      component: require './tabs/preferences-accounts'
      order: 2
    })
    PreferencesSectionStore.registerPreferenceSection(new Cfg {
      icon: 'ic-settings-shortcuts.png'
      sectionId: 'Shortcuts'
      displayName: 'Shortcuts'
      component: require './tabs/preferences-keymaps'
      order: 3
    })

    WorkspaceStore.defineSheet 'Preferences', {},
      split: ['Preferences']
      list: ['Preferences']

    PreferencesRoot = require('./preferences-root')
    ComponentRegistry.register PreferencesRoot,
      location: WorkspaceStore.Location.Preferences

    Actions.openPreferences.listen(@_openPreferences)
    ipcRenderer.on 'open-preferences', => @_openPreferences()

  _openPreferences: ->
    ipcRenderer.send 'command', 'application:show-main-window'
    if WorkspaceStore.topSheet() isnt WorkspaceStore.Sheet.Preferences
      Actions.pushSheet(WorkspaceStore.Sheet.Preferences)

  deactivate: ->

  serialize: -> @state
