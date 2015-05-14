_ = require 'underscore-plus'
Reflux = require 'reflux'
request = require 'request'
{Contact, ContactStore, DatabaseStore, FocusedContactsStore} = require 'inbox-exports'

module.exports =
FullContactStore = Reflux.createStore

  init: ->
    @_loadContactDataFromAPI = _.debounce(_.bind(@__loadContactDataFromAPI, @), 50)
    # @_cachedContactData = {}
    @_resolvedFocusedContact = null
    @_loadFocusedContact = _.debounce(_.bind(@_loadFocusedContact, @), 20)
    @_loadFocusedContact()

    @listenTo ContactStore, @_loadFocusedContact
    @listenTo FocusedContactsStore, @_loadFocusedContact

  focusedContact: -> @_resolvedFocusedContact

  # We need to pull fresh from the database so when we update data in the
  # for the contact, we get it anew.
  _loadFocusedContact: ->
    contact = FocusedContactsStore.focusedContact()
    if contact
      @_resolvedFocusedContact = contact
      DatabaseStore.findBy(Contact, email: contact.email).then (contact) =>
        @_resolvedFocusedContact = contact
        if contact and not contact.thirdPartyData?["FullContact"]?
          @_loadContactDataFromAPI(contact)
        @trigger()
    else
      @_resolvedFocusedContact = null
      @trigger()

  __loadContactDataFromAPI: (contact) ->
    # Swap the url's to see real data
    email = contact.email.toLowerCase().trim()
    return if email.length is 0
    url = "https://api.fullcontact.com/v2/person.json?email=#{email}&apiKey=eadcbaf0286562a"
    request url, (err, resp, data) =>
      return {} if err
      return {} if resp.statusCode != 200
      try
        data = JSON.parse data
        contact = @_mergeDataIntoContact(contact, data)
        DatabaseStore.persistModel(contact).then => @trigger(@)

  _mergeDataIntoContact: (contact, data) ->
    contact.title = data.organizations?[0]?["title"]
    contact.company = data.organizations?[0]?["name"]
    contact.thirdPartyData ?= {}
    contact.thirdPartyData["FullContact"] = data
    return contact
