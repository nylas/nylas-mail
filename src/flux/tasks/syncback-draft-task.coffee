_ = require 'underscore'

Actions = require '../actions'
AccountStore = require '../stores/account-store'
DatabaseStore = require '../stores/database-store'
TaskQueueStatusStore = require '../stores/task-queue-status-store'
NylasAPI = require '../nylas-api'

Task = require './task'
SyncbackMetadataTask = require './syncback-metadata-task'
{APIError} = require '../errors'
Message = require '../models/message'
Account = require '../models/account'

# MutateDraftTask

module.exports =
class SyncbackDraftTask extends Task

  constructor: (@draftClientId) ->
    super

  shouldDequeueOtherTask: (other) ->
    other instanceof SyncbackDraftTask and
    other.draftClientId is @draftClientId and
    other.creationDate <= @creationDate

  isDependentTask: (other) ->
    other instanceof SyncbackDraftTask and
    other.draftClientId is @draftClientId and
    other.creationDate <= @creationDate

  performLocal: ->
    # SyncbackDraftTask does not do anything locally. You should persist your changes
    # to the local database directly or using a DraftStoreProxy, and then queue a
    # SyncbackDraftTask to send those changes to the server.
    if not @draftClientId
      errMsg = "Attempt to call SyncbackDraftTask.performLocal without @draftClientId"
      return Promise.reject(new Error(errMsg))
    Promise.resolve()

  performRemote: ->
    @getLatestLocalDraft().then (draft) =>
      return Promise.resolve() unless draft

      @checkDraftFromMatchesAccount(draft)
      .then(@saveDraft)
      .then(@updateLocalDraft)
      .thenReturn(Task.Status.Success)
      .catch (err) =>
        if err instanceof APIError and not (err.statusCode in NylasAPI.PermanentErrorCodes)
          return Promise.resolve(Task.Status.Retry)
        return Promise.resolve([Task.Status.Failed, err])

  saveDraft: (draft) =>
    if draft.serverId
      path = "/drafts/#{draft.serverId}"
      method = 'PUT'
    else
      path = "/drafts"
      method = 'POST'

    NylasAPI.makeRequest
      accountId: draft.accountId
      path: path
      method: method
      body: draft.toJSON()
      returnsModel: false

  updateLocalDraft: ({version, id, thread_id}) =>
    # Important: There could be a significant delay between us initiating the save
    # and getting JSON back from the server. Our local copy of the draft may have
    # already changed more.
    #
    # The only fields we want to update from the server are the `id` and `version`.
    #
    draftIsNew = false

    DatabaseStore.inTransaction (t) =>
      @getLatestLocalDraft().then (draft) =>
        # Draft may have been deleted. Oh well.
        return Promise.resolve() unless draft
        if draft.serverId isnt id
          draft.threadId = thread_id
          draft.serverId = id
          draftIsNew = true
        draft.version = version
        t.persistModel(draft).then =>
          Promise.resolve(draft)
    .then (draft) =>
      if draftIsNew
        for {pluginId, value} in draft.pluginMetadata
          task = new SyncbackMetadataTask(@draftClientId, draft.constructor.name, pluginId)
          Actions.queueTask(task)
      return true

  getLatestLocalDraft: =>
    DatabaseStore.findBy(Message, clientId: @draftClientId).include(Message.attributes.body)

  checkDraftFromMatchesAccount: (draft) ->
    account = AccountStore.accountForEmail(draft.from[0].email)
    if draft.accountId is account.id
      return Promise.resolve(draft)
    else
      if draft.serverId
        NylasAPI.incrementRemoteChangeLock(Message, draft.serverId)
        NylasAPI.makeRequest
          path: "/drafts/#{draft.serverId}"
          accountId: draft.accountId
          method: "DELETE"
          body: {version: draft.version}
          returnsModel: false

      draft.accountId = account.id
      delete draft.serverId
      delete draft.version
      delete draft.threadId
      delete draft.replyToMessageId
      DatabaseStore.inTransaction (t) =>
        t.persistModel(draft)
      .thenReturn(draft)
