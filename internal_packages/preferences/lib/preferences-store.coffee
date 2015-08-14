Reflux = require 'reflux'
_ = require 'underscore'
NylasStore = require 'nylas-store'
{Actions} = require 'nylas-exports'

class PreferencesStore extends NylasStore
  constructor: ->
    @_tabs = []
    @listenTo Actions.registerPreferencesTab, @_registerTab

  tabs: =>
    @_tabs

  _registerTab: (tabConfig) =>
    @_tabs.push(tabConfig)
    @_triggerSoon ?= _.debounce(( => @trigger()), 20)
    @_triggerSoon()

module.exports = new PreferencesStore()
