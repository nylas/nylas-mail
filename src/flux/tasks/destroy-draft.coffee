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
  constructor: ({@draftLocalId, @draftId} = {}) -> super

  shouldDequeueOtherTask: (other) ->
    if @draftLocalId
      (other instanceof DestroyDraftTask and other.draftLocalId is @draftLocalId) or
      (other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId) or
      (other instanceof SendDraftTask and other.draftLocalId is @draftLocalId) or
      (other instanceof FileUploadTask and other.messageLocalId is @draftLocalId)
    else if @draftId
      (other instanceof DestroyDraftTask and other.draftLocalId is @draftLocalId)
    else
      false

  shouldWaitForTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId)

  performLocal: ->
    if @draftLocalId
      find = DatabaseStore.findByLocalId(Message, @draftLocalId)
    else if @draftId
      find = DatabaseStore.find(Message, @draftId)
    else
      return Promise.reject(new Error("Attempt to call DestroyDraftTask.performLocal without draftLocalId or draftId"))

    find.then (draft) =>
      return Promise.resolve() unless draft
      @draft = draft
      DatabaseStore.unpersistModel(draft)

  performRemote: ->
    # We don't need to do anything if we weren't able to find the draft
    # when we performed locally, or if the draft has never been synced to
    # the server (id is still self-assigned)
    return Promise.resolve(Task.Status.Finished) unless @draft
    return Promise.resolve(Task.Status.Finished) unless @draft.isSaved() and @draft.version?

    NylasAPI.makeRequest
      path: "/drafts/#{@draft.id}"
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
