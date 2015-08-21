Task = require './task'
{APIError} = require '../errors'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
NylasAPI = require '../nylas-api'
_ = require 'underscore'

module.exports =
class MarkMessageReadTask extends Task

  constructor: (@message) ->
    super

  performLocal: ->
    # update the flag on the message
    @_previousUnreadState = @message.unread
    @message.unread = false

    # dispatch an action to persist it
    DatabaseStore.persistModel(@message)

  performRemote: ->
    # queue the operation to the server
    NylasAPI.makeRequest
      path: "/messages/#{@message.id}"
      accountId: @message.accountId
      method: 'PUT'
      body:
        unread: false
      returnsModel: true
    .then =>
      return Promise.resolve(Task.Status.Finished)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        # Run performLocal backwards to undo the tag changes
        @message.unread = @_previousUnreadState
        DatabaseStore.persistModel(@message).then =>
          return Promise.resolve(Task.Status.Finished)
      else
        return Promise.resolve(Task.Status.Retry)
