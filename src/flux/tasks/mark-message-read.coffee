Task = require './task'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
_ = require 'underscore-plus'

class MarkMessageReadTask extends Task

  constructor: (@message) ->
    @

  rollbackLocal: ->
    new Promise (resolve, reject) =>
      unless @_previousUnreadState?
        reject(new Error("Cannot call rollbackLocal without previous call to performLocal"))
      @message.unread = @_previousUnreadState
      DatabaseStore.persistModel(@message).then(resolve).catch(reject)

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
      atom.inbox.makeRequest {
        path: "/n/#{@message.namespaceId}/messages/#{@message.id}"
        method: 'PUT'
        body: {
          unread: false
        }
        returnsModel: true
        success: resolve
        error: reject
      }

module.exports = MarkMessageReadTask
