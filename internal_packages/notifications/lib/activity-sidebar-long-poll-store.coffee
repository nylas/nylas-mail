{Actions} = require 'nylas-exports'
NylasStore = require 'nylas-store'

class AccountSidebarLongPollStore extends NylasStore
  constructor: ->
    @listenTo Actions.longPollReceivedRawDeltasPing, (n) => @trigger(n)

module.exports = new AccountSidebarLongPollStore()
