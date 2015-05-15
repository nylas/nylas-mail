Task = require './task'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
NylasAPI = require '../inbox-api'
_ = require 'underscore-plus'

module.exports =
class MarkMessageReadTask extends Task

  constructor: (@message) ->
    super

  performLocal: ->
    new Promise (resolve, reject) =>
      # update the flag on the message
      @_previousUnreadState = @message.unread
      @message.unread = false

      # dispatch an action to persist it
      DatabaseStore.persistModel(@message).then(resolve).catch(reject)

  performRemote: ->
    new Promise (resolve, reject) =>
      # queue the operation to the server
      NylasAPI.makeRequest {
        path: "/n/#{@message.namespaceId}/messages/#{@message.id}"
        method: 'PUT'
        body: {
          unread: false
        }
        returnsModel: true
        success: resolve
        error: reject
      }

  # We don't really care if this fails.
  onAPIError: -> Promise.resolve()
  onOtherError: -> Promise.resolve()
  onTimeoutError: -> Promise.resolve()
  onOfflineError: -> Promise.resolve()

  _rollbackLocal: ->
    new Promise (resolve, reject) =>
      unless @_previousUnreadState?
        reject(new Error("Cannot call rollbackLocal without previous call to performLocal"))
      @message.unread = @_previousUnreadState
      DatabaseStore.persistModel(@message).then(resolve).catch(reject)
