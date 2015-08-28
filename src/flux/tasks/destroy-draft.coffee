Task = require './task'
{APIError} = require '../errors'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
NylasAPI = require '../nylas-api'

SyncbackDraftTask = require './syncback-draft'
SendDraftTask = require './send-draft'
FileUploadTask = require './file-upload-task'

module.exports =
class DestroyDraftTask extends Task
  constructor: ({@draftClientId, @draftId} = {}) -> super

  shouldDequeueOtherTask: (other) ->
    if @draftClientId
      (other instanceof DestroyDraftTask and other.draftClientId is @draftClientId) or
      (other instanceof SyncbackDraftTask and other.draftClientId is @draftClientId) or
      (other instanceof SendDraftTask and other.draftClientId is @draftClientId) or
      (other instanceof FileUploadTask and other.messageClientId is @draftClientId)
    else if @draftId
      (other instanceof DestroyDraftTask and other.draftClientId is @draftClientId)
    else
      false

  shouldWaitForTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftClientId is @draftClientId)

  performLocal: ->
    if @draftClientId
      find = DatabaseStore.findBy(Message, clientId: @draftClientId)
    else if @draftId
      find = DatabaseStore.find(Message, @draftId)
    else
      return Promise.reject(new Error("Attempt to call DestroyDraftTask.performLocal without draftClientId"))

    find.include(Message.attributes.body).then (draft) =>
      return Promise.resolve() unless draft
      @draft = draft
      DatabaseStore.unpersistModel(draft)

  performRemote: ->
    # We don't need to do anything if we weren't able to find the draft
    # when we performed locally, or if the draft has never been synced to
    # the server (id is still self-assigned)
    return Promise.resolve(Task.Status.Finished) unless @draft
    return Promise.resolve(Task.Status.Finished) unless @draft.serverId and @draft.version?

    NylasAPI.makeRequest
      path: "/drafts/#{@draft.serverId}"
      accountId: @draft.accountId
      method: "DELETE"
      body:
        version: @draft.version
      returnsModel: false
    .then =>
      return Promise.resolve(Task.Status.Finished)
    .catch APIError, (err) =>
      inboxMsg = err.body?.message ? ""

      # Draft has already been deleted, this is not really an error
      if err.statusCode is 404
        return Promise.resolve(Task.Status.Finished)

      # Draft has been sent, and can't be deleted. Not much we can do but finish
      if inboxMsg.indexOf("is not a draft") >= 0
        return Promise.resolve(Task.Status.Finished)

      if err.statusCode in NylasAPI.PermanentErrorCodes
        Actions.postNotification({message: "Unable to delete this draft. Restoring...", type: "error"})
        DatabaseStore.persistModel(@draft).then =>
          return Promise.resolve(Task.Status.Finished)

      Promise.resolve(Task.Status.Retry)
