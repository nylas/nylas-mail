Reflux = require 'reflux'
NamespaceStore = require './namespace-store'
Actions = require '../actions'

WorkspaceStore = Reflux.createStore
  init: ->
    @_resetInstanceVars()
    @listenTo Actions.selectView, @_onSelectView

  _resetInstanceVars: ->
    @_view = 'threads'

  # Inbound Events

  _onSelectView: (view) ->
    @_view = view
    @trigger(@)

  # Accessing Data

  selectedView: ->
    @_view

module.exports = WorkspaceStore
