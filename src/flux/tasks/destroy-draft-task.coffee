Task = require './task'
{APIError} = require '../errors'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
NylasAPI = require '../nylas-api'
BaseDraftTask = require './base-draft-task'

module.exports =
class DestroyDraftTask extends BaseDraftTask
  constructor: (@draftClientId) ->
    super(@draftClientId)

  shouldDequeueOtherTask: (other) ->
    other instanceof BaseDraftTask and other.draftClientId is @draftClientId

  performLocal: ->
    super
    @refreshDraftReference().then =>
      DatabaseStore.inTransaction (t) =>
        t.unpersistModel(@draft)

  performRemote: ->
    # We don't need to do anything if we weren't able to find the draft
    # when we performed locally, or if the draft has never been synced to
    # the server (id is still self-assigned)
    if not @draft
      err = new Error("No valid draft to destroy!")
      return Promise.resolve([Task.Status.Failed, err])

    if not @draft.serverId
      return Promise.resolve(Task.Status.Continue)

    if not @draft.version?
      err = new Error("Can't destroy draft without a version or serverId")
      return Promise.resolve([Task.Status.Failed, err])

    NylasAPI.incrementRemoteChangeLock(Message, @draft.serverId)
    NylasAPI.makeRequest
      path: "/drafts/#{@draft.serverId}"
      accountId: @draft.accountId
      method: "DELETE"
      body:
        version: @draft.version
      returnsModel: false
    .then =>
      # We deliberately do not decrement the change count, ensuring no deltas
      # about this object are received that could restore it.
      return Promise.resolve(Task.Status.Success)
    .catch APIError, (err) =>
      NylasAPI.decrementRemoteChangeLock(Message, @draft.serverId)

      inboxMsg = err.body?.message ? ""

      # Draft has already been deleted, this is not really an error
      if err.statusCode in [404, 409]
        return Promise.resolve(Task.Status.Continue)

      # Draft has been sent, and can't be deleted. Not much we can do but finish
      if inboxMsg.indexOf("is not a draft") >= 0
        return Promise.resolve(Task.Status.Continue)

      if err.statusCode in NylasAPI.PermanentErrorCodes
        Actions.postNotification({message: "Unable to delete this draft. Restoring...", type: "error"})
        DatabaseStore.inTransaction (t) =>
          t.persistModel(@draft)
        .then =>
          Promise.resolve(Task.Status.Failed)
      else
        Promise.resolve(Task.Status.Retry)
