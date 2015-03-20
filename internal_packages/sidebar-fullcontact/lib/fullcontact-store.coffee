_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'

{Utils,
 Actions,
 MessageStore,
 NamespaceStore} = require 'inbox-exports'

module.exports =
FullContactStore = Reflux.createStore

  init: ->
    # @listenTo Actions.getFullContactDetails, @_makeDataRequest
    @listenTo Actions.selectThreadId, @_onSelectThreadId
    @listenTo Actions.focusContact, @_focusContact
    @listenTo MessageStore, @_onMessageStoreChanged
    @listenTo NamespaceStore, @_onNamespaceChanged

    @_cachedContactData = {}

    @_currentThreadId = null
    @_clearCurrentParticipants(silent: true)

    @_onNamespaceChanged()

  sortedContacts: -> @_currentContacts

  focusedContact: -> @_currentFocusedContact

  fullContactCache: ->
    emails = {}
    emails[contact.email] = contact for contact in @_currentContacts
    fullContactCache = {}
    _.each @_cachedContactData, (fullContactData, email) ->
      if email of emails then fullContactCache[email] = fullContactData
    return fullContactCache

  _clearCurrentParticipants: ({silent}={}) ->
    @_contactScores = {}
    @_currentContacts = []
    @_currentFocusedContact = null
    @trigger() unless silent

  _onSelectThreadId: (id) ->
    @_currentThreadId = id
    @_clearCurrentParticipants()
    # We need to wait now for the MessageStore to grab all of the
    # appropriate messages for the given thread.

  _onMessageStoreChanged: ->
    if MessageStore.threadId() is @_currentThreadId
      @_setCurrentParticipants()
    else
      @_clearCurrentParticipants()

  _onNamespaceChanged: ->
    @_myEmail = (NamespaceStore.current()?.me().email ? "").toLowerCase().trim()

  # For now we take the last message
  _setCurrentParticipants: ->
    @_scoreAllParticipants()
    sorted = _.sortBy(_.values(@_contactScores), "score").reverse()
    @_currentContacts = _.map(sorted, (obj) -> obj.contact)
    @_focusContact(@_currentContacts[0], silent: true)
    @trigger()

  _focusContact: (contact, {silent}={}) ->
    return unless contact
    @_currentFocusedContact = contact
    if not @_cachedContactData[contact.email]
      @_fetchAPIData(contact.email)
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
    return if @_contactScores[contact.nameEmail()]? # only assign the first time

    penalties = @_calculatePenalties(contact, score)

    @_contactScores[contact.nameEmail()] =
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

  _fetchAPIData: (email) ->
    # Swap the url's to see real data
    url = 'https://api.fullcontact.com/v2/person.json?email='+email+'&apiKey=61c8a2325df0471f'
    # url = 'https://gist.githubusercontent.com/KartikTalwar/885f1ad03bc64914cfe2/raw/ce369b03089c2b334334824a78b3512e6a4a5ebe/fullcontact1.json'
    request url, (err, resp, data) =>
      return {} if err
      return {} if resp.statusCode != 200
      try
        data = JSON.parse data
        console.log data
        @_cachedContactData[email] = data
        @trigger(@)
