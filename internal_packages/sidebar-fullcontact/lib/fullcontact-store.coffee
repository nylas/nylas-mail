_ = require 'underscore'
Reflux = require 'reflux'
request = require 'request'
{Contact,
 AccountStore
 ContactStore,
 DatabaseStore,
 FocusedContactsStore} = require 'nylas-exports'

FullContactStore = Reflux.createStore
  init: ->

  dataForContact: (contact) ->
    return {} unless contact
    if contact.thirdPartyData["FullContact"]
      return contact.thirdPartyData["FullContact"]
    else
      @_attachFullcontactDataToContact(contact)
      return {}

  _attachFullcontactDataToContact: (contact) ->
    email = contact.email.toLowerCase().trim()
    return if email.length is 0

    url = "https://api.fullcontact.com/v2/person.json?email=#{email}&apiKey=eadcbaf0286562a"
    request url, (err, resp, data) =>
      return if err
      return if resp.statusCode != 200
      try
        data = JSON.parse(data)
        contact.title = data.organizations?[0]?["title"]
        contact.company = data.organizations?[0]?["name"]
        contact.thirdPartyData ?= {}
        contact.thirdPartyData["FullContact"] = data

        DatabaseStore.inTransaction (t) =>
          t.persistModel(contact)
        .then =>
          @trigger()

module.exports = FullContactStore
