fs = require 'fs'
path = require 'path'
Rx = require 'rx-lite'
Actions = require('../actions').default
Contact = require('../models/contact').default
Utils = require '../models/utils'
NylasStore = require 'nylas-store'
RegExpUtils = require '../../regexp-utils'
DatabaseStore = require('./database-store').default
AccountStore = require('./account-store').default
ComponentRegistry = require('../../registries/component-registry')
_ = require 'underscore'

###
Public: ContactStore provides convenience methods for searching contacts and
formatting contacts. When Contacts become editable, this store will be expanded
with additional actions.

Section: Stores
###
class ContactStore extends NylasStore

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
    extensions = ComponentRegistry.findComponentsMatching({
      role: "ContactSearchResults"
    })

    if not search or search.length is 0
      return Promise.resolve([])

    # If we haven't found enough items in memory, query for more from the
    # database. Note that we ask for LIMIT * accountCount because we want to
    # return contacts with distinct email addresses, and the same contact
    # could exist in every account. Rather than make SQLite do a SELECT DISTINCT
    # (which is very slow), we just ask for more items.
    query = DatabaseStore.findAll(Contact)
      .search(search)
      .limit(limit * accountCount)
      .order(Contact.attributes.refs.descending())
    query.then (results) =>
      # remove query results that were already found in ranked contacts
      results = @_distinctByEmail(results)
      return Promise.each extensions, (ext) =>
        return ext.findAdditionalContacts(search, results).then (contacts) =>
          results = contacts
      .then =>
        if (results.length > limit) then results.length = limit
        return Promise.resolve(results)

  isValidContact: (contact) =>
    return false unless contact instanceof Contact
    return contact.isValid()

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

  _distinctByEmail: (contacts) =>
    # remove query results that are duplicates, prefering ones that have names
    uniq = {}
    for contact in contacts
      continue unless contact.email
      key = contact.email.toLowerCase()
      existing = uniq[key]
      if not existing or (not existing.name or existing.name is existing.email)
        uniq[key] = contact
    _.values(uniq)

module.exports = new ContactStore()
