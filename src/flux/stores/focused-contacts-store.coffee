_ = require 'underscore'
Rx = require 'rx-lite'

Utils = require '../models/utils'
Actions = require '../actions'
NylasStore = require 'nylas-store'
Thread = require('../models/thread').default
Contact = require '../models/contact'
MessageStore = require './message-store'
AccountStore = require './account-store'
DatabaseStore = require './database-store'
FocusedContentStore = require './focused-content-store'

# A store that handles the focuses collections of and individual contacts
class FocusedContactsStore extends NylasStore
  constructor: ->
    @listenTo MessageStore, @_onMessageStoreChanged
    @listenTo Actions.focusContact, @_onFocusContact
    @_clearCurrentParticipants()

  sortedContacts: -> @_currentContacts

  focusedContact: -> @_currentFocusedContact

  focusedContactThreads: -> @_currentParticipantThreads ? []

  # We need to wait now for the MessageStore to grab all of the
  # appropriate messages for the given thread.

  _onMessageStoreChanged: =>
    threadId = if MessageStore.itemsLoading() then null else MessageStore.threadId()

    # Always clear data immediately when we're showing the wrong thread
    if @_currentThread and @_currentThread.id isnt threadId
      @_clearCurrentParticipants()
      @trigger()

    # Wait to populate until the user has stopped moving through threads. This is
    # important because the FocusedContactStore powers tons of third-party extensions,
    # which could do /horrible/ things when we trigger.
    @_onMessageStoreChangeThrottled ?= _.debounce =>
      thread = if MessageStore.itemsLoading() then null else MessageStore.thread()
      if thread and thread.id isnt @_currentThread?.id
        @_currentThread = thread
        @_popuateCurrentParticipants()
    , 250
    @_onMessageStoreChangeThrottled()

  # For now we take the last message
  _popuateCurrentParticipants: ->
    @_scoreAllParticipants()
    sorted = _.sortBy(_.values(@_contactScores), "score").reverse()
    @_currentContacts = _.map(sorted, (obj) -> obj.contact)
    @_onFocusContact(@_currentContacts[0])

  _clearCurrentParticipants: ->
    @_contactScores = {}
    @_currentContacts = []
    @_unsubFocusedContact?.dispose()
    @_unsubFocusedContact = null
    @_currentFocusedContact = null
    @_currentThread = null
    @_currentParticipantThreads = []

  _onFocusContact: (contact) =>
    @_unsubFocusedContact?.dispose()
    @_unsubFocusedContact = null
    @_currentParticipantThreads = []

    if contact
      query = DatabaseStore.findBy(Contact, {
        email: contact.email,
        accountId: @_currentThread.accountId
      })
      @_unsubFocusedContact = Rx.Observable.fromQuery(query).subscribe (match) =>
        @_currentFocusedContact = match ? contact
        @trigger()
      @_loadCurrentParticipantThreads(contact.email)
    else
      @_currentFocusedContact = null
      @trigger()

  _loadCurrentParticipantThreads: (email) ->
    DatabaseStore.findAll(Thread).where(Thread.attributes.participants.contains(email)).limit(100).then (threads = []) =>
      @_currentParticipantThreads = threads
      @trigger()

  # We score everyone to determine who's the most relevant to display in
  # the sidebar.
  _scoreAllParticipants: ->
    score = (message, msgNum, field, multiplier) =>
      for contact, j in (message[field] ? [])
        bonus = message[field].length - j
        @_assignScore(contact, (msgNum+1) * multiplier + bonus)

    for message, msgNum in MessageStore.items() by -1
      if message.draft
        score(message, msgNum, "to",   10000)
        score(message, msgNum, "cc",   1000)
      else
        score(message, msgNum, "from", 100)
        score(message, msgNum, "to",   10)
        score(message, msgNum, "cc",   1)

    return @_contactScores

  # Self always gets a score of 0
  _assignScore: (contact, score=0) ->
    return unless contact and contact.email
    return if contact.email.trim().length is 0

    key = Utils.toEquivalentEmailForm(contact.email)

    @_contactScores[key] ?=
      contact: contact
      score: score - @_calculatePenalties(contact, score)

  _calculatePenalties: (contact, score) ->
    penalties = 0
    email = contact.email.toLowerCase().trim()
    myEmail = AccountStore.accountForId(@_currentThread?.accountId)?.emailAddress

    if email is myEmail
      # The whole thing which will penalize to zero
      penalties += score

    notCommonDomain = not Utils.emailHasCommonDomain(myEmail)
    sameDomain = Utils.emailsHaveSameDomain(myEmail, email)
    if notCommonDomain and sameDomain
      penalties += score * 0.9

    return Math.max(penalties, 0)

module.exports = new FocusedContactsStore
