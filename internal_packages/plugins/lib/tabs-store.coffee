_ = require 'underscore'
ipc = require 'ipc'
Reflux = require 'reflux'

PluginsActions = require './plugins-actions'

module.exports =
TabsStore = Reflux.createStore

  init: ->
    @_tabIndex = 0
    @listenTo(PluginsActions.selectTabIndex, @_onTabIndexChanged)

  # Getters

  tabIndex: ->
    @_tabIndex

  # Action Handlers

  _onTabIndexChanged: (idx) ->
    @_tabIndex = idx
    @trigger(@)
