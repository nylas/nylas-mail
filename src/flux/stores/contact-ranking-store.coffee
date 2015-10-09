
NylasStore = require 'nylas-store'
DatabaseStore = require './database-store'
AccountStore = require './account-store'

class ContactRankingStore extends NylasStore

  constructor: ->
    @listenTo DatabaseStore, @_onDatabaseChanged
    @listenTo AccountStore, @_onAccountChanged
    @_value = null
    @_accountId = null
    @_refresh()

  _onDatabaseChanged: (change) =>
    if change.objectClass is 'JSONObject' and change.objects[0].key is "ContactRankingsFor#{@_accountId}"
      @_value = change.objects[0].json.value
      @trigger()

  _onAccountChanged: =>
    @_refresh()
    @reset()
    @trigger()

  value: ->
    @_value

  reset: ->
    @_value = null

  _refresh: =>
    return if @_accountId is AccountStore.current()?.id
    @_accountId = AccountStore.current()?.id
    DatabaseStore.findJSONObject("ContactRankingsFor#{@_accountId}").then (json) =>
      @_value = if json? then json.value else null
      @trigger()


module.exports = new ContactRankingStore()
