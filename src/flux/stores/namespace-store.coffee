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
      @_items = namespaces
      @_current = _.find @_items, (n) -> n.id == @_current?.id

      unless @_current
        @_current = @_items?[0]
        if @_current
          atom.inbox.getCollection(@_current.id, "contacts")

      @trigger(@)

  # Inbound Events

  onDataChanged: (change) ->
    return unless change && change.objectClass == Namespace.name
    @populateItems()

  onSelectNamespaceId: (id) ->
    @_current = _.find @_items, (n) -> n.id == @_current.id
    @trigger(@)

  # Exposed Data

  items: ->
    @_items

  current: ->
    @_current

module.exports = NamespaceStore
