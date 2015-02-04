Reflux = require 'reflux'
request = require 'request'

{Actions, MessageStore} = require 'inbox-exports'

module.exports =
FullContactStore = Reflux.createStore

  init: ->
    @listenTo Actions.getFullContactDetails, @_makeDataRequest
    @_emailData = {}

  _makeDataRequest: (email) ->
    if @_emailData[email]?
      @trigger(@)
    else
      # Swap the url's to see real data
      # url = 'https://api.fullcontact.com/v2/person.json?email='+email+'&apiKey=61c8a2325df0471f'
      url = 'https://gist.githubusercontent.com/KartikTalwar/885f1ad03bc64914cfe2/raw/ce369b03089c2b334334824a78b3512e6a4a5ebe/fullcontact1.json'
      request url, (err, resp, data) =>
        return {} if err
        return {} if resp.statusCode != 200
        @_emailData[email] = JSON.parse data
        @trigger(@)

  getDataFromEmail: (email) ->
    @_emailData[email] ? {}