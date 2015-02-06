Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
_ = require 'underscore-plus'

module.exports = ContactStore = Reflux.createStore
  init: ->
    @namespaceId = null
    @listenTo NamespaceStore, @onNamespaceChanged
    @listenTo DatabaseStore, @onDataChanged

  onNamespaceChanged: ->
    @onDataChanged()

  onDataChanged: (change) ->
    return if change && change.objectClass != Contact.name
    DatabaseStore.findAll(Contact).then (contacts) =>
      @_all = contacts
      @trigger(@)

  searchContacts: (search) ->
    return [] if not search or search.length is 0
    search = search.toLowerCase()
    matches = _.filter @_all, (contact) ->
      return true if contact.email?.toLowerCase().indexOf(search) == 0
      return true if contact.name?.toLowerCase().indexOf(search) == 0
      false
    matches = matches[0..4] if matches.length > 5
    matches
