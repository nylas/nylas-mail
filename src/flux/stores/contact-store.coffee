Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
_ = require 'underscore-plus'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

###
Public: ContactStore maintains an in-memory cache of the user's address
book, making it easy to build autocompletion functionality and resolve
the names associated with email addresses.

## Listening for Changes

The ContactStore monitors the {DatabaseStore} for changes to {Contact} models
and triggers when contacts have changed, allowing your stores and components
to refresh data based on the ContactStore.

```coffee
@unsubscribe = ContactStore.listen(@_onContactsChanged, @)

_onContactsChanged: ->
  # refresh your contact results
```

Section: Stores
###
class ContactStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_contactCache = []
    @_namespaceId = null
    @listenTo DatabaseStore, @_onDatabaseChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_refreshCache()

  # Public: Search the user's contact list for the given search term.
  # This method compares the `search` string against each Contact's
  # `name` and `email`.
  #
  # - `search` {String} A search phrase, such as `ben@n` or `Ben G`
  # - `options` (optional) {Object} If you will only be displaying a few results,
  #   you should pass a limit value. {::searchContacts} will return as soon
  #   as `limit` matches have been found.
  #
  # Returns an {Array} of matching {Contact} models
  #
  searchContacts: (search, {limit}={}) =>
    return [] if not search or search.length is 0

    limit ?= 5
    limit = Math.max(limit, 0)
    search = search.toLowerCase()

    matchFunction = (contact) ->
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

  __refreshCache: =>
    new Promise (resolve, reject) =>
      DatabaseStore.findAll(Contact)
      .then (contacts=[]) =>
        @_contactCache = contacts
        @trigger()
        resolve()
      .catch(reject)
  _refreshCache: _.debounce(ContactStore::__refreshCache, 20)

  _onDatabaseChanged: (change) =>
    return unless change?.objectClass is Contact.name
    @_refreshCache()

  _resetCache: =>
    @_contactCache = []
    @trigger(@)

  _onNamespaceChanged: =>
    return if @_namespaceId is NamespaceStore.current()?.id
    @_namespaceId = NamespaceStore.current()?.id

    if @_namespaceId
      @_refreshCache()
    else
      @_resetCache()


module.exports = new ContactStore()
