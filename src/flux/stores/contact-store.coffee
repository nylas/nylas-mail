fs = require 'fs'
path = require 'path'
Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
Utils = require '../models/utils'
NylasStore = require 'nylas-store'
RegExpUtils = require '../../regexp-utils'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
ContactRankingStore = require './contact-ranking-store'
_ = require 'underscore'

WindowBridge = require '../../window-bridge'

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
class ContactStore extends NylasStore

  constructor: ->
    if atom.isMainWindow() or atom.inSpecMode()
      @_contactCache = []
      @_accountId = null

      @listenTo DatabaseStore, @_onDatabaseChanged
      @listenTo AccountStore, @_onAccountChanged
      @listenTo ContactRankingStore, @_sortContactsCacheWithRankings

      @_accountId = AccountStore.current()?.id
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
  searchContacts: (search, options={}) =>
    {limit, noPromise} = options
    if not atom.isMainWindow()
      if noPromise
        throw new Error("We search Contacts in the Main window, which makes it impossible for this to be a noPromise method from this window")
      # Returns a promise that resolves to the value of searchContacts
      return WindowBridge.runInMainWindow("ContactStore", "searchContacts", [search, options])

    if not search or search.length is 0
      if noPromise
        return []
      else
        return Promise.resolve([])

    limit ?= 5
    limit = Math.max(limit, 0)
    search = search.toLowerCase()

    matchFunction = (contact) ->
      # For the time being, we never return contacts that are missing
      # email addresses
      return false unless contact.email
      # - email (bengotow@gmail.com)
      # - email domain (test@bengotow.com)
      # - name parts (Ben, Go)
      # - name full (Ben Gotow)
      #   (necessary so user can type more than first name ie: "Ben Go")
      if contact.email
        i = contact.email.toLowerCase().indexOf(search)
        return true if i is 0 or i is contact.email.indexOf('@') + 1
      if contact.name
        return true if contact.name.toLowerCase().indexOf(search) is 0

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

    if noPromise
      return matches
    else
      return Promise.resolve(matches)

  # Public: Returns true if the contact provided is a {Contact} instance and
  # contains a properly formatted email address.
  #
  isValidContact: (contact) =>
    return false unless contact instanceof Contact
    return false unless contact.email

    # The email regexp must match the /entire/ email address
    [match] = RegExpUtils.emailRegex().exec(contact.email)
    return match is contact.email

  parseContactsInString: (contactString, options={}) =>
    {skipNameLookup} = options
    if not atom.isMainWindow()
      # Returns a promise that resolves to the value of searchContacts
      return WindowBridge.runInMainWindow("ContactStore", "parseContactsInString", [contactString, options])
    detected = []
    emailRegex = RegExpUtils.emailRegex()
    lastMatchEnd = 0

    while (match = emailRegex.exec(contactString))
      email = match[0]
      name = null

      hasLeadingParen  = contactString[match.index-1] in ['(','<']
      hasTrailingParen = contactString[match.index+email.length] in [')','>']

      if hasLeadingParen and hasTrailingParen
        nameStart = lastMatchEnd
        for char in [',', '\n', '\r']
          i = contactString.lastIndexOf(char, match.index)
          nameStart = i+1 if i+1 > nameStart
        name = contactString.substr(nameStart, match.index - 1 - nameStart).trim()

      if (not name or name.length is 0) and not skipNameLookup
        # Look to see if we can find a name for this email address in the ContactStore.
        # Otherwise, just populate the name with the email address.
        existing = @searchContacts(email, {limit:1, noPromise: true})[0]
        if existing and existing.name
          name = existing.name
        else
          name = email

      # The "nameStart" for the next match must begin after lastMatchEnd
      lastMatchEnd = match.index+email.length
      if hasTrailingParen
        lastMatchEnd += 1

      if name
        # If the first and last character of the name are quotation marks, remove them
        [first,...,last] = name
        if first in ['"', "'"] and last in ['"', "'"]
          name = name[1...-1]

      detected.push(new Contact({email, name}))

    return Promise.resolve(detected)

  __refreshCache: =>
    return unless @_accountId

    DatabaseStore.findAll(Contact).where(Contact.attributes.accountId.equal(@_accountId)).then (contacts=[]) =>
      @_contactCache = contacts
      @_sortContactsCacheWithRankings()
      @trigger()
    .catch (err) =>
      console.warn("Request for Contacts failed. #{err}")
  _refreshCache: _.debounce(ContactStore::__refreshCache, 100)

  _sortContactsCacheWithRankings: =>
    rankings = ContactRankingStore.value()
    return unless rankings
    @_contactCache = _.sortBy @_contactCache, (contact) =>
      - (rankings[contact.email.toLowerCase()] ? 0) / 1

  _onDatabaseChanged: (change) =>
    return unless change?.objectClass is Contact.name
    @_refreshCache()

  _resetCache: =>
    @_contactCache = []
    ContactRankingStore.reset()
    @trigger(@)

  _onAccountChanged: =>
    return if @_accountId is AccountStore.current()?.id
    @_accountId = AccountStore.current()?.id

    if @_accountId
      @_refreshCache()
    else
      @_resetCache()


module.exports = new ContactStore()
