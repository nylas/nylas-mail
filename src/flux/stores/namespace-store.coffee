Reflux = require 'reflux'
Actions = require '../actions'
Namespace = require '../models/namespace'
DatabaseStore = require './database-store'
_ = require 'underscore-plus'

# The ThreadStore listens to changes to the avaialble namespaces in the database
# and manages the currently selected namespace.

NamespaceStore = Reflux.createStore
  init: ->
    @_items = []
    @_current = null

    @listenTo Actions.selectNamespaceId, @onSelectNamespaceId
    @listenTo DatabaseStore, @onDataChanged
    @populateItems()

  populateItems: ->
    DatabaseStore.findAll(Namespace).then (namespaces) =>
      @_namespaces = namespaces
      @_current = _.find @_namespaces, (n) -> n.id == @_current?.id

      @_current = @_namespaces?[0] unless @_current

      @trigger(@)

  # Inbound Events

  onDataChanged: (change) ->
    return unless change && change.objectClass == Namespace.name
    @populateItems()

  onSelectNamespaceId: (id) ->
    @_current = _.find @_namespaces, (n) -> n.id == @_current.id
    @trigger(@)

  # Exposed Data

  items: ->
    @_namespaces

  current: ->
    @_current

module.exports = NamespaceStore
