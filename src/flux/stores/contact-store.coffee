fs = require 'fs'
path = require 'path'
Reflux = require 'reflux'
Rx = require 'rx-lite'
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
Public: ContactStore provides convenience methods for searching contacts and
formatting contacts. When Contacts become editable, this store will be expanded
with additional actions.

Section: Stores
###
class ContactStore extends NylasStore

  constructor: ->
    @_rankedContacts = []
    @listenTo ContactRankingStore, => @_updateRankedContactCache()
    @_updateRankedContactCache()

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
    {limit} = options
    limit ?= 5
    limit = Math.max(limit, 0)

    search = search.toLowerCase()
    accountCount = AccountStore.accounts().length

    return Promise.resolve([]) if not search or search.length is 0

    # Search ranked contacts which are stored in order in memory
    results = []
    for contact in @_rankedContacts
      if (contact.email.toLowerCase().indexOf(search) isnt -1 or
          contact.name.toLowerCase().indexOf(search) isnt -1)
        results.push(contact)
      if results.length is limit
        return Promise.resolve(results)

    # If we haven't found enough items in memory, query for more from the
    # database. Note that we ask for LIMIT * accountCount because we want to
    # return contacts with distinct email addresses, and the same contact
    # could exist in every account. Rather than make SQLite do a SELECT DISTINCT
    # (which is very slow), we just ask for more items.
    query = DatabaseStore.findAll(Contact).whereAny([
      Contact.attributes.name.like(search),
      Contact.attributes.email.like(search)
    ])
    query.limit(limit * accountCount)
    query.then (queryResults) =>
      existingEmails = _.pluck(results, 'email')

      # remove query results that were already found in ranked contacts
      queryResults = _.reject queryResults, (c) -> c.email in existingEmails
      queryResults = @_distinctByEmail(queryResults)

      results = results.concat(queryResults)
      results.length = limit if results.length > limit

      return Promise.resolve(results)

  # Public: Returns true if the contact provided is a {Contact} instance and
  # contains a properly formatted email address.
  #
  isValidContact: (contact) =>
    return false unless contact instanceof Contact
    return false unless contact.email

    # The email regexp must match the /entire/ email address
    result = RegExpUtils.emailRegex().exec(contact.email)
    if result and result instanceof Array
      return result[0] is contact.email
    else return false

  parseContactsInString: (contactString, options={}) =>
    {skipNameLookup} = options

    detected = []
    emailRegex = RegExpUtils.emailRegex()
    lastMatchEnd = 0

    while (match = emailRegex.exec(contactString))
      email = match[0]
      name = null

      startsWithQuote = email[0] in ['\'','"']
      hasTrailingQuote = contactString[match.index+email.length] in ['\'','"']
      if startsWithQuote and hasTrailingQuote
        email = email[1..-1]

      hasLeadingParen  = contactString[match.index-1] in ['(','<']
      hasTrailingParen = contactString[match.index+email.length] in [')','>']

      if hasLeadingParen and hasTrailingParen
        nameStart = lastMatchEnd
        for char in [',', '\n', '\r']
          i = contactString.lastIndexOf(char, match.index)
          nameStart = i+1 if i+1 > nameStart
        name = contactString.substr(nameStart, match.index - 1 - nameStart).trim()

      # The "nameStart" for the next match must begin after lastMatchEnd
      lastMatchEnd = match.index+email.length
      if hasTrailingParen
        lastMatchEnd += 1

      if not name or name.length is 0
        name = email

      # If the first and last character of the name are quotation marks, remove them
      [firstChar,...,lastChar] = name
      if firstChar in ['"', "'"] and lastChar in ['"', "'"]
        name = name[1...-1]

      detected.push(new Contact({email, name}))

    if skipNameLookup
      return Promise.resolve(detected)

    Promise.all detected.map (contact) =>
      return contact if contact.name isnt contact.email
      @searchContacts(contact.email, {limit: 1}).then ([match]) =>
        return match if match and match.email is contact.email
        return contact

  _updateRankedContactCache: =>
    rankings = ContactRankingStore.valuesForAllAccounts()
    emails = Object.keys(rankings)

    if emails.length is 0
      @_rankedContacts = []
      return

    # Sort the emails by rank and then clip to 400 so that our ranked cache
    # has a bounded size.
    emails = _.sortBy emails, (email) ->
      (- (rankings[email.toLowerCase()] ? 0) / 1)
    emails.length = 400 if emails.length > 400

    DatabaseStore.findAll(Contact, {email: emails}).then (contacts) =>
      contacts = @_distinctByEmail(contacts)
      for contact in contacts
        contact._rank = (- (rankings[contact.email.toLowerCase()] ? 0) / 1)
      @_rankedContacts = _.sortBy contacts, (contact) -> contact._rank

  _distinctByEmail: (contacts) =>
    # remove query results that are duplicates, prefering ones that have names
    uniq = {}
    for contact in contacts
      key = contact.email.toLowerCase()
      existing = uniq[key]
      if not existing or (not existing.name or existing.name is existing.email)
        uniq[key] = contact
    _.values(uniq)

  _resetCache: =>
    @_rankedContacts = []
    ContactRankingStore.reset()
    @trigger(@)

module.exports = new ContactStore()
