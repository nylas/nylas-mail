_ = require 'underscore'
DatabaseStore = require '../stores/database-store'
Task = require './task'
Message = require '../models/message'
{APIError} = require '../errors'

class DraftNotFoundError extends Error
  constructor: ->
    super

class BaseDraftTask extends Task

  constructor: (@draftClientId) ->
    @draft = null
    super

  shouldDequeueOtherTask: (other) ->
    isSameDraft = other.draftClientId is @draftClientId
    isOlderTask = other.sequentialId < @sequentialId
    isExactClass = other.constructor.name is @constructor.name
    return isSameDraft and isOlderTask and isExactClass

  isDependentOnTask: (other) ->
    # Set this task to be dependent on any SyncbackDraftTasks and
    # SendDraftTasks for the same draft that were created first.
    # This, in conjunction with this method on SendDraftTask, ensures
    # that a send and a syncback never run at the same time for a draft.

    # Require here rather than on top to avoid a circular dependency
    isSameDraft = other.draftClientId is @draftClientId
    isOlderTask = other.sequentialId < @sequentialId
    isSaveOrSend = other instanceof BaseDraftTask

    return isSameDraft and isOlderTask and isSaveOrSend

  performLocal: ->
    # SyncbackDraftTask does not do anything locally. You should persist your changes
    # to the local database directly or using a DraftStoreProxy, and then queue a
    # SyncbackDraftTask to send those changes to the server.
    if not @draftClientId
      errMsg = "Attempt to call #{@constructor.name}.performLocal without a draftClientId"
      return Promise.reject(new Error(errMsg))
    Promise.resolve()

  refreshDraftReference: =>
    DatabaseStore
    .findBy(Message, clientId: @draftClientId)
    .include(Message.attributes.body)
    .then (message) =>
      unless message and message.draft
        return Promise.reject(new DraftNotFoundError())
      @draft = message
      return Promise.resolve(message)


BaseDraftTask.DraftNotFoundError = DraftNotFoundError
module.exports = BaseDraftTask
