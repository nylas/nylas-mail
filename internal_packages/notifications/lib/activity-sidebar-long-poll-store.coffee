{Actions} = require 'nylas-exports'
NylasStore = require 'nylas-store'

class AccountSidebarLongPollStore extends NylasStore
  constructor: ->
    @listenTo Actions.longPollReceivedRawDeltasPing, => @trigger()

module.exports = new AccountSidebarLongPollStore()
