_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'
{FocusedContactsStore} = require 'inbox-exports'

module.exports =
FullContactStore = Reflux.createStore

  init: ->
    @_cachedContactData = {}
    @listenTo FocusedContactsStore, @_onFocusedContacts

  sortedContacts: -> FocusedContactsStore.sortedContacts()
  focusedContact: -> FocusedContactsStore.focusedContact()

  fullContactCache: ->
    emails = {}
    contacts = FocusedContactsStore.sortedContacts()
    emails[contact.email] = contact for contact in contacts
    fullContactCache = {}
    _.each @_cachedContactData, (fullContactData, email) ->
      if email of emails then fullContactCache[email] = fullContactData
    return fullContactCache

  _onFocusedContacts: ->
    contact = FocusedContactsStore.focusedContact() ? {}
    if not @_cachedContactData[contact.email]
      @_fetchAPIData(contact.email)
    @trigger()

  _fetchAPIData: (email) ->
    # Swap the url's to see real data
    url = 'https://api.fullcontact.com/v2/person.json?email='+email+'&apiKey=61c8a2325df0471f'
    # url = 'https://gist.githubusercontent.com/KartikTalwar/885f1ad03bc64914cfe2/raw/ce369b03089c2b334334824a78b3512e6a4a5ebe/fullcontact1.json'
    request url, (err, resp, data) =>
      return {} if err
      return {} if resp.statusCode != 200
      try
        data = JSON.parse data
        @_cachedContactData[email] = data
        @trigger(@)
