fs = require 'fs'
path = require 'path'
Reflux = require 'reflux'
Actions = require '../actions'
Contact = require '../models/contact'
Utils = require '../models/utils'
NylasStore = require 'nylas-store'
RegExpUtils = require '../../regexp-utils'
DatabaseStore = require './database-store'
NamespaceStore = require './namespace-store'
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

- `localPath`: path on disk to keep the cache

- `version`: a version number. If the local cache has a different version number
  it will be thrown out. Useful if you want to change the format of the data
  stored in the cache.

- `maxAge`: the maximum age of the local cache before it should be refreshed.

###
class JSONCache
  @include: CoffeeHelpers.includeModule

  @include Publisher

  constructor: ({@localPath, @version, @maxAge}) ->
    @_value = null
    @readLocal()

  detatch: =>
    clearInterval(@_interval) if @_interval

  value: ->
    @_value

  reset: ->
    fs.unlink @localPath, (err) ->
      console.error(err)
    @_value = null

  readLocal: =>
    fs.exists @localPath, (exists) =>
      return @refresh() unless exists
      fs.readFile @localPath, (err, contents) =>
        return @refresh() unless contents and not err
        try
          json = JSON.parse(contents)
          if json.version isnt @version
            throw new Error("Outdated schema")
          if not json.time
            throw new Error("No fetch time present")
          @_value = json.value
          @trigger()

          age = (new Date).getTime() - json.time
          if age > @maxAge
            @refresh()
          else
            setTimeout(@refresh, @maxAge - age)

        catch err
          console.error(err)
          @reset()
          @refresh()

  writeLocal: =>
    json =
      version: @version
      time: (new Date).getTime()
      value: @_value
    fs.writeFile(@localPath, JSON.stringify(json))

  refresh: =>
    clearInterval(@_interval) if @_interval
    @_interval = setInterval(@refresh, @maxAge)

    @refreshValue (newValue) =>
      @_value = newValue
      @writeLocal()
      @trigger()

  refreshValue: (callback) =>
    throw new Error("Subclasses should override this method.")


class RankingsJSONCache extends JSONCache

  refreshValue: (callback) =>
    return unless atom.isMainWindow()

    nsid = NamespaceStore.current()?.id
    return unless nsid
    NylasAPI.makeRequest
      path: "/n/#{nsid}/contacts/rankings"
      returnsModel: false
    .then (json) =>
      # Check that the current namespace is still the one we requested data for
      return unless nsid is NamespaceStore.current()?.id
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
    @_namespaceId = null

    @_rankingsCache = new RankingsJSONCache
      localPath: path.join(atom.getConfigDirPath(), 'contact-rankings.json')
      maxAge: 60 * 60 * 1000 * 24 # one day
      version: 1

    @listenTo DatabaseStore, @_onDatabaseChanged
    @listenTo NamespaceStore, @_onNamespaceChanged
    @listenTo @_rankingsCache, @_sortContactsCacheWithRankings

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
    DatabaseStore.findAll(Contact).then (contacts=[]) =>
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

  _onNamespaceChanged: =>
    return if @_namespaceId is NamespaceStore.current()?.id
    @_namespaceId = NamespaceStore.current()?.id

    if @_namespaceId
      @_rankingsCache.refresh()
      @_refreshCache()
    else
      @_resetCache()


module.exports = new ContactStore()
