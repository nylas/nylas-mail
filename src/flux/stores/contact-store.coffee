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
_ = require 'underscore'

NylasAPI = require '../nylas-api'
{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

###
The JSONCache class exposes a simple API for maintaining a local cache of data
in a JSON file that needs to be refreshed periodically. Using JSONCache is a good
idea because it handles a file errors and JSON parsing errors gracefully.

To use the JSONCache class, subclass it and implement `refreshValue`, which
should compute a new JSON value and return it via the callback:

```
refreshValue: (callback) ->
  NylasAPI.makeRequest(...).then (values) ->
    callback(values)
```

If you do not wish to refresh the value, do not call the callback.

When you create an instance of a JSONCache, you need to provide several settings:

- `key`: A unique key identifying this object.

- `version`: a version number. If the local cache has a different version number
  it will be thrown out. Useful if you want to change the format of the data
  stored in the cache.

- `maxAge`: the maximum age of the local cache before it should be refreshed.

###
class JSONCache
  @include: CoffeeHelpers.includeModule
  @include Publisher

  constructor: ({@key, @version, @maxAge}) ->
    @_value = null
    DatabaseStore.findJSONObject(@key).then (json) =>
      return @refresh() unless json
      return @refresh() unless json.version is @version
      @_value = json.value
      @trigger()

      age = (new Date).getTime() - json.time
      if age > @maxAge
        @refresh()
      else
        setTimeout(@refresh, @maxAge - age)

  value: ->
    @_value

  reset: ->
    DatabaseStore.persistJSONObject(@key, {})
    clearInterval(@_interval) if @_interval
    @_interval = null
    @_value = null

  refresh: =>
    clearInterval(@_interval) if @_interval
    @_interval = setInterval(@refresh, @maxAge)

    @refreshValue (newValue) =>
      @_value = newValue
      DatabaseStore.persistJSONObject(@key, {
        version: @version
        time: (new Date).getTime()
        value: @_value
      })
      @trigger()

  refreshValue: (callback) =>
    throw new Error("Subclasses should override this method.")


class RankingsJSONCache extends JSONCache

  constructor: ->
    super(key: 'RankingsJSONCache', version: 1, maxAge: 60 * 60 * 1000 * 24)

  refreshValue: (callback) =>
    return unless atom.isWorkWindow()

    accountId = AccountStore.current()?.id
    return unless accountId

    NylasAPI.makeRequest
      accountId: accountId
      path: "/contacts/rankings"
      returnsModel: false
    .then (json) =>
      # Check that the current account is still the one we requested data for
      return unless accountId is AccountStore.current()?.id
      # Convert rankings into the format needed for quick lookup
      rankings = {}
      for [email, rank] in json
        rankings[email.toLowerCase()] = rank
      callback(rankings)
    .catch (err) =>
      console.warn("Request for Contact Rankings failed. #{err}")


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
    @_contactCache = []
    @_accountId = null

    @_rankingsCache = new RankingsJSONCache()
    @listenTo DatabaseStore, @_onDatabaseChanged
    @listenTo AccountStore, @_onAccountChanged
    @listenTo @_rankingsCache, @_sortContactsCacheWithRankings

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

    matches

  # Public: Returns true if the contact provided is a {Contact} instance and
  # contains a properly formatted email address.
  #
  isValidContact: (contact) =>
    return false unless contact instanceof Contact
    return contact.email and RegExpUtils.emailRegex().test(contact.email)

  parseContactsInString: (contactString, {skipNameLookup}={}) =>
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
        existing = @searchContacts(email, {limit:1})[0]
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

    detected

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
    rankings = @_rankingsCache.value()
    return unless rankings
    @_contactCache = _.sortBy @_contactCache, (contact) =>
      - (rankings[contact.email.toLowerCase()] ? 0) / 1

  _onDatabaseChanged: (change) =>
    return unless change?.objectClass is Contact.name
    @_refreshCache()

  _resetCache: =>
    @_contactCache = []
    @_rankingsCache.reset()
    @trigger(@)

  _onAccountChanged: =>
    return if @_accountId is AccountStore.current()?.id
    @_accountId = AccountStore.current()?.id

    if @_accountId
      @_rankingsCache.refresh()
      @_refreshCache()
    else
      @_resetCache()


module.exports = new ContactStore()
