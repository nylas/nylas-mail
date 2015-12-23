_ = require 'underscore'
Task = require './task'
Thread = require '../models/thread'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
MailRulesProcessor = require '../../mail-rules-processor'
async = require 'async'

class ReprocessMailRulesTask extends Task
  constructor: (@accountId) ->
    @_processed ?= 0
    @_offset ?= 0
    @_finished = false
    super

  label: ->
    "Applying Mail Rules..."

  numberOfImpactedItems: ->
    @_offset

  cancel: ->
    @_finished = true

  performRemote: ->
    Promise.fromNode(@_processAllMessages).thenReturn(Task.Status.Success)

  _processAllMessages: (callback) =>
    async.until ( => @_finished), @_processSomeMessages, callback

  _processSomeMessages: (callback) =>
    # Fetching threads first, and then getting their messages allows us to use
    # The same indexes as the thread list / message list in the app
    query = DatabaseStore
      .findAll(Thread, {accountId: @accountId})
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      .offset(@_offset)
      .limit(50)

    query.then (threads) =>
      if threads.length is 0
        @_finished = true

      return Promise.resolve(null) if @_finished

      DatabaseStore.findAll(Message, threadId: _.pluck(threads, 'id')).then (messages) =>
        return Promise.resolve(null) if @_finished

        MailRulesProcessor.processMessages(messages).finally =>
          @_processed += messages.length
          @_offset += threads.length

    .delay(500)
    .asCallback(callback)

module.exports = ReprocessMailRulesTask
