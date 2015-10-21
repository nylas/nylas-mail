_ = require 'underscore'

Actions = require '../actions'
AccountStore = require '../stores/account-store'
DatabaseStore = require '../stores/database-store'
TaskQueueStatusStore = require '../stores/task-queue-status-store'
NylasAPI = require '../nylas-api'

Task = require './task'
{APIError} = require '../errors'
Message = require '../models/message'
Account = require '../models/account'

FileUploadTask = require './file-upload-task'

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

  # We want to wait for other SyncbackDraftTasks to run, but we don't want
  # to get dequeued if they fail.
  onDependentTaskError: ->
    return Task.DO_NOT_DEQUEUE_ME

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
      # The draft may have been deleted by another task. Nothing we can do.
      return Promise.resolve() unless draft
      @checkDraftFromMatchesAccount(draft).then (draft) =>

        if draft.serverId
          path = "/drafts/#{draft.serverId}"
          method = 'PUT'
        else
          path = "/drafts"
          method = 'POST'

        payload = draft.toJSON()
        @submittedBody = payload.body
        delete payload['from']

        # We keep this in memory as a fallback in case
        # `getLatestLocalDraft` returns null after we make our API
        # request.
        oldDraft = draft

        NylasAPI.makeRequest
          accountId: draft.accountId
          path: path
          method: method
          body: payload
          returnsModel: false

        .then (json) =>
          # Important: There could be a significant delay between us initiating the save
          # and getting JSON back from the server. Our local copy of the draft may have
          # already changed more.
          #
          # The only fields we want to update from the server are the `id` and `version`.
          #
          # Also note that this *could* still rollback a save between the find / persist
          # below. We currently have no way of locking between processes. Maybe a
          # log-style data structure would be better suited for drafts.
          #
          DatabaseStore.atomically =>
            @getLatestLocalDraft().then (draft) ->
              if not draft then draft = oldDraft
              draft.version = json.version
              draft.serverId = json.id
              DatabaseStore.persistModel(draft)

        .then =>
          return Promise.resolve(Task.Status.Success)

        .catch APIError, (err) =>
          if err.statusCode in [400, 404, 409] and err.requestOptions?.method is 'PUT'
            @getLatestLocalDraft().then (draft) =>
              if not draft then draft = oldDraft
              @detatchFromRemoteID(draft).then ->
                return Promise.resolve(Task.Status.Retry)
          else
            # NOTE: There's no offline handling. If we're offline
            # SyncbackDraftTasks should always fail.
            #
            # We don't roll anything back locally, but this failure
            # ensures that SendDraftTasks can never succeed while offline.
            Promise.resolve([Task.Status.Failed, err])

  getLatestLocalDraft: =>
    DatabaseStore.findBy(Message, clientId: @draftClientId).include(Message.attributes.body)

  checkDraftFromMatchesAccount: (draft) ->
    account = AccountStore.itemWithEmailAddress(draft.from[0].email)
    if draft.accountId is account.id
      return Promise.resolve(draft)
    else
      DestroyDraftTask = require './destroy-draft'
      destroy = new DestroyDraftTask(draftId: existingAccountDraft.id)
      promise = TaskQueueStatusStore.waitForPerformLocal(destroy).then =>
        @detatchFromRemoteID(existingAccountDraft, acct.id).then (newAccountDraft) =>
          Promise.resolve(newAccountDraft)
      Actions.queueTask(destroy)
      return promise

  detatchFromRemoteID: (draft, newAccountId = null) ->
    return Promise.resolve() unless draft
    newDraft = new Message(draft)
    newDraft.accountId = newAccountId if newAccountId

    delete newDraft.serverId
    delete newDraft.version
    delete newDraft.threadId
    delete newDraft.replyToMessageId

    DatabaseStore.persistModel(newDraft)
