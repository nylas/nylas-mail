Task = require './task'
{APIError} = require '../errors'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
NylasAPI = require '../nylas-api'

SyncbackDraftTask = require './syncback-draft-task'
SendDraftTask = require './send-draft-task'

module.exports =
class DestroyDraftTask extends Task
  constructor: ({@draftClientId} = {}) ->
    super

  shouldDequeueOtherTask: (other) ->
    (other instanceof DestroyDraftTask and other.draftClientId is @draftClientId) or
    (other instanceof SyncbackDraftTask and other.draftClientId is @draftClientId) or
    (other instanceof SendDraftTask and other.draftClientId is @draftClientId)

  isDependentTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftClientId is @draftClientId)

  performLocal: ->
    unless @draftClientId
      return Promise.reject(new Error("Attempt to call DestroyDraftTask.performLocal without draftClientId"))

    DatabaseStore.findBy(Message, clientId: @draftClientId).include(Message.attributes.body).then (draft) =>
      return Promise.resolve() unless draft
      @draft = draft
      DatabaseStore.inTransaction (t) =>
        t.unpersistModel(draft)

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

    NylasAPI.makeRequest
      path: "/drafts/#{@draft.serverId}"
      accountId: @draft.accountId
      method: "DELETE"
      body:
        version: @draft.version
      returnsModel: false
    .then =>
      return Promise.resolve(Task.Status.Success)
    .catch APIError, (err) =>
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
