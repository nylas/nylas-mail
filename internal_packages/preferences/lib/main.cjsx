PreferencesStore = require './preferences-store'

module.exports =
  activate: (@state={}) ->
    ipc = require 'ipc'
    React = require 'react'
    {Actions} = require('nylas-exports')

    Actions.registerPreferencesTab({
      icon: 'ic-settings-general.png'
      name: 'General'
      component: require './tabs/preferences-general'
    })
    Actions.registerPreferencesTab({
      icon: 'ic-settings-accounts.png'
      name: 'Accounts'
      component: require './tabs/preferences-accounts'
    })
    # Actions.registerPreferencesTab({
    #   icon: 'ic-settings-mailrules.png'
    #   name: 'Mail Rules'
    #   component: require './tabs/preferences-mailrules'
    # })
    Actions.registerPreferencesTab({
      icon: 'ic-settings-shortcuts.png'
      name: 'Shortcuts'
      component: require './tabs/preferences-keymaps'
    })
    Actions.registerPreferencesTab({
      icon: 'ic-settings-notifications.png'
      name: 'Notifications'
      component: require './tabs/preferences-notifications'
    })
    Actions.registerPreferencesTab({
      icon: 'ic-settings-appearance.png'
      name: 'Appearance'
      component: require './tabs/preferences-appearance'
    })

    # Actions.registerPreferencesTab({
    #   icon: 'ic-settings-signatures.png'
    #   name: 'Signatures'
    #   component: require './tabs/preferences-signatures'
    # })

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
