Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
_ = require 'underscore-plus'

module.exports = ContactStore = Reflux.createStore

  init: ->
    @_contactCache = []
    @_namespaceId = null
    @listenTo DatabaseStore, @_onDatabaseChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_refreshCache()

  searchContacts: (search, {limit}={}) ->
    return [] if not search or search.length is 0

    limit ?= 5
    limit = Math.max(limit, 0)
    search = search.toLowerCase()

    matchFunction = (contact) ->
      # For a given contact, check:
      # - email (bengotow@gmail.com)
      # - name parts (Ben, Go)
      # - name full (Ben Gotow)
      #   (necessary so user can type more than first name ie: "Ben Go")
      return true if contact.email?.toLowerCase().indexOf(search) is 0
      return true if contact.name?.toLowerCase().indexOf(search) is 0
      name = contact.name?.toLowerCase() ? ""
      for namePart in name.split(/\s/)
        return true if namePart.indexOf(search) is 0
      false

    matches = []
    for contact in @_contactCache
      if matchFunction(contact)
        matches.push(contact)
        if matches.length is limit
          break

    matches

  _refreshCache: ->
    new Promise (resolve, reject) =>
      DatabaseStore.findAll(Contact)
      .then (contacts=[]) =>
        @_contactCache = contacts
        @trigger()
        resolve()
      .catch(reject)

  _onDatabaseChanged: (change) ->
    return unless change?.objectClass is Contact.name
    @_refreshCache()

  _resetCache: ->
    @_contactCache = []
    @trigger(@)

  _onNamespaceChanged: ->
    return if @_namespaceId is NamespaceStore.current()?.id
    @_namespaceId = NamespaceStore.current()?.id

    if @_namespaceId
      @_refreshCache()
    else
      @_resetCache()
