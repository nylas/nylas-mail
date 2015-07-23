Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
Utils = require '../models/utils'
RegExpUtils = require '../../regexp-utils'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
_ = require 'underscore'

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
      # For the time being, we never return contacts that are missing
      # email addresses
      return false unless contact.email
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

  parseContactsInString: (contactString, {skipNameLookup}={}) =>
    detected = []
    emailRegex = RegExpUtils.emailRegex()
    while (match = emailRegex.exec(contactString))
      email = match[0]
      name = null

      hasLeadingParen  = contactString[match.index-1] in ['(','<']
      hasTrailingParen = contactString[match.index+email.length] in [')','>']

      if hasLeadingParen and hasTrailingParen
        nameStart = 0
        for char in ['>', ')', ',', '\n', '\r']
          i = contactString.lastIndexOf(char, match.index)
          nameStart = i+1 if i+1 > nameStart
        name = contactString.substr(nameStart, match.index - 1 - nameStart).trim()

      if (not name or name.length is 0) and not skipNameLookup
        # Look to see if we can find a name for this email address in the ContactStore.
        # Otherwise, just populate the name with the email address.
        existing = @searchContacts(email, {limit:1})[0]
        if existing and existing.name
          name = existing.name
        else
          name = email

      detected.push(new Contact({email, name}))
    detected

  __refreshCache: =>
    new Promise (resolve, reject) =>
      DatabaseStore.findAll(Contact)
      .then (contacts=[]) =>
        @_contactCache = contacts
        @trigger()
        resolve()
      .catch (err) ->
        console.warn("Request for Contacts failed. #{err}")
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
