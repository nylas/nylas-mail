Actions = require '../actions'
Namespace = require '../models/namespace'
DatabaseStore = require './database-store'
_ = require 'underscore'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

saveStateKey = "nylas.current_namespace"

###
Public: The NamespaceStore listens to changes to the available namespaces in
the database and exposes the currently active Namespace via {::current}

Section: Stores
###
class NamespaceStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_items = []
    @_current = null
    @_namespaces = []

    saveState = atom.config.get(saveStateKey)
    if saveState and _.isObject(saveState)
      savedNamespace = (new Namespace).fromJSON(saveState)
      if savedNamespace.usesLabels() or savedNamespace.usesFolders()
        @_current = savedNamespace
        @_namespaces = [@_current]

    @listenTo Actions.selectNamespaceId, @onSelectNamespaceId
    @listenTo DatabaseStore, @onDataChanged

    @populateItems()

  populateItems: =>
    DatabaseStore.findAll(Namespace).then (namespaces) =>
      current = _.find namespaces, (n) -> n.id is @_current?.id
      current = namespaces?[0] unless current

      if current and (current.usesLabels() or current.usesFolders())
        if not _.isEqual(current, @_current) or not _.isEqual(namespaces, @_namespaces)
          atom.config.set(saveStateKey, current)
          @_current = current
          @_namespaces = namespaces
          @trigger(@)
      else
        DatabaseStore.unpersistModel(current) if current
        atom.config.unset(saveStateKey)
    .catch (err) =>
      console.warn("Request for Namespaces failed. #{err}", err.stack)

  # Inbound Events

  onDataChanged: (change) =>
    return unless change && change.objectClass == Namespace.name
    @populateItems()

  onSelectNamespaceId: (id) =>
    return if @_current?.id is id
    @_current = _.find @_namespaces, (n) -> n.id == @_current.id
    @trigger(@)

  # Exposed Data

  # Public: Returns an {Array} of {Namespace} objects
  items: =>
    @_namespaces

  # Public: Returns the currently active {Namespace}.
  current: =>
    @_current

module.exports = new NamespaceStore()
