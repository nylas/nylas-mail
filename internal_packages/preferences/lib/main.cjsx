{PreferencesSectionStore} = require 'nylas-exports'

module.exports =
  activate: (@state={}) ->
    ipc = require 'ipc'
    React = require 'react'
    {Actions} = require('nylas-exports')

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
    PreferencesSectionStore.registerPreferenceSection(new Cfg {
      icon: 'ic-settings-notifications.png'
      sectionId: 'Notifications'
      displayName: 'Notifications'
      component: require './tabs/preferences-notifications'
      order: 4
    })
    PreferencesSectionStore.registerPreferenceSection(new Cfg {
      icon: 'ic-settings-appearance.png'
      sectionId: 'Appearance'
      displayName: 'Appearance'
      component: require './tabs/preferences-appearance'
      order: 5
    })

    Actions.openPreferences.listen(@_openPreferences)
    ipc.on 'open-preferences', => @_openPreferences()

  _openPreferences: ({tab} = {}) ->
    {ReactRemote} = require('nylas-exports')
    Preferences = require('./preferences')
    ReactRemote.openWindowForComponent(Preferences, {
      tag: 'preferences'
      title: "Preferences"
      width: 520
      resizable: false
      autosize: true
      stylesheetRegex: /(preferences|nylas\-fonts)/
      props: {
        initialTab: tab
      }
    })

  deactivate: ->

  serialize: -> @state
