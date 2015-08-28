_ = require 'underscore'

Utils = require '../models/utils'
Actions = require '../actions'
NylasStore = require 'nylas-store'
MessageStore = require './message-store'
AccountStore = require './account-store'
FocusedContentStore = require './focused-content-store'

# A store that handles the focuses collections of and individual contacts
class FocusedContactsStore extends NylasStore
  constructor: ->
    @listenTo Actions.focusContact, @_focusContact
    @listenTo MessageStore, @_onMessageStoreChanged
    @listenTo AccountStore, @_onAccountChanged
    @listenTo FocusedContentStore, @_onFocusChanged

    @_currentThread = null
    @_clearCurrentParticipants(silent: true)

    @_onAccountChanged()

  sortedContacts: -> @_currentContacts

  focusedContact: -> @_currentFocusedContact

  _clearCurrentParticipants: ({silent}={}) ->
    @_contactScores = {}
    @_currentContacts = []
    @_currentFocusedContact = null
    @trigger() unless silent

  _onFocusChanged: (change) =>
    return unless change.impactsCollection('thread')
    item = FocusedContentStore.focused('thread')
    return if @_currentThread?.id is item?.id
    @_currentThread = item
    @_clearCurrentParticipants()
    @_onMessageStoreChanged()

    # We need to wait now for the MessageStore to grab all of the
    # appropriate messages for the given thread.

  _onMessageStoreChanged: =>
    if MessageStore.threadId() is @_currentThread?.id
      @_setCurrentParticipants()
    else
      @_clearCurrentParticipants()

  _onAccountChanged: =>
    @_myEmail = (AccountStore.current()?.me().email ? "").toLowerCase().trim()

  # For now we take the last message
  _setCurrentParticipants: ->
    @_scoreAllParticipants()
    sorted = _.sortBy(_.values(@_contactScores), "score").reverse()
    @_currentContacts = _.map(sorted, (obj) -> obj.contact)
    @_focusContact(@_currentContacts[0], silent: true)
    @trigger()

  _focusContact: (contact, {silent}={}) =>
    return unless contact
    @_currentFocusedContact = contact
    @trigger() unless silent

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
    return unless contact?.email
    return if contact.email.trim().length is 0
    return if @_contactScores[contact.toString()]? # only assign the first time

    penalties = @_calculatePenalties(contact, score)

    @_contactScores[contact.toString()] =
      contact: contact
      score: score - penalties

  _calculatePenalties: (contact, score) ->
    penalties = 0
    email = contact.email.toLowerCase().trim()

    if email is @_myEmail
      penalties += score # The whole thing which will penalize to zero

    notCommonDomain = not Utils.emailHasCommonDomain(@_myEmail)
    sameDomain = Utils.emailsHaveSameDomain(@_myEmail, email)
    if notCommonDomain and sameDomain
      penalties += score * 0.9

    return Math.max(penalties, 0)

  _matchesDomain: (myEmail, email) ->
    myDomain = _.last(myEmail.split("@"))
    theirDomain = _.last(email.split("@"))
    return myDomain.length > 0 and theirDomain.length > 0 and myDomain is theirDomain

module.exports = new FocusedContactsStore
