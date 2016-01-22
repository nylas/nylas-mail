{PreferencesUIStore,
 Actions,
 WorkspaceStore,
 ComponentRegistry} = require 'nylas-exports'
{ipcRenderer} = require 'electron'

module.exports =

  activate: ->
    React = require 'react'

    Cfg = PreferencesUIStore.TabItem

    PreferencesUIStore.registerPreferencesTab(new Cfg {
      tabId: 'General'
      displayName: 'General'
      component: require './tabs/preferences-general'
      order: 1
    })
    PreferencesUIStore.registerPreferencesTab(new Cfg {
      tabId: 'Accounts'
      displayName: 'Accounts'
      component: require './tabs/preferences-accounts'
      order: 2
    })
    PreferencesUIStore.registerPreferencesTab(new Cfg {
      tabId: 'Shortcuts'
      displayName: 'Shortcuts'
      component: require './tabs/preferences-keymaps'
      order: 3
    })
    PreferencesUIStore.registerPreferencesTab(new Cfg {
      tabId: 'Mail Rules'
      displayName: 'Mail Rules'
      component: require './tabs/preferences-mail-rules'
      componentRequiresAccount: true
      order: 4
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
