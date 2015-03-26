Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
_ = require 'underscore-plus'

module.exports = ContactStore = Reflux.createStore

  BATCH_SIZE: 500 # Num contacts to pull at once

  init: ->
    @_contactCache = []
    @_namespaceId = null
    @listenTo DatabaseStore, @_onDBChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_refreshCacheFromDB()

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

  _refreshCacheFromDB: ->
    new Promise (resolve, reject) =>
      DatabaseStore.findAll(Contact)
      .then (contacts=[]) =>
        @_contactCache = contacts
        @trigger()
        resolve()
      .catch(reject)

  _refreshDBFromAPI: (params={}) ->
    new Promise (resolve, reject) =>
      requestOptions =
        success: (json) =>
          if json.length > 0
            @_refreshDBFromAPI
              limit: @BATCH_SIZE
              offset: params.offset + json.length
            .then(resolve).catch(reject)
          else resolve(json)
        error: reject
      atom.inbox.getCollection(@_namespaceId, "contacts", params, requestOptions)

  _onDBChanged: (change) ->
    return unless change?.objectClass is Contact.name
    @_refreshCacheFromDB()

  _resetCache: ->
    @_contactCache = []
    @trigger(@)

  _onNamespaceChanged: ->
    return if @_namespaceId is NamespaceStore.current()?.id
    @_namespaceId = NamespaceStore.current()?.id

    if @_namespaceId
      @_refreshDBFromAPI(limit: @BATCH_SIZE, offset: 0) if atom.state.mode is 'editor'
      @_refreshCacheFromDB()
    else
      @_resetCache()
