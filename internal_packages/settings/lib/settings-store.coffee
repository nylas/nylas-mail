_ = require 'underscore'
ipc = require 'ipc'
Reflux = require 'reflux'

SettingsActions = require './settings-actions'

module.exports =
SettingsStore = Reflux.createStore

  init: ->
    @_tabIndex = 0
    @listenTo(SettingsActions.selectTabIndex, @_onTabIndexChanged)

  # Getters

  tabIndex: ->
    @_tabIndex

  # Action Handlers

  _onTabIndexChanged: (idx) ->
    @_tabIndex = idx
    @trigger(@)
