{isTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
Message = require '../models/message'
{APIError} = require '../errors'
Task = require './task'
TaskQueue = require '../stores/task-queue'
SyncbackDraftTask = require './syncback-draft'
FileUploadTask = require './file-upload-task'
NylasAPI = require '../nylas-api'

module.exports =
class SendDraftTask extends Task

  constructor: (@draftLocalId, {@fromPopout}={}) ->
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draftLocalId is @draftLocalId

  shouldWaitForTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId) or
    (other instanceof FileUploadTask and other.messageLocalId is @draftLocalId)

  performLocal: ->
    # When we send drafts, we don't update anything in the app until
    # it actually succeeds. We don't want users to think messages have
    # already sent when they haven't!
    if not @draftLocalId
      return Promise.reject(new Error("Attempt to call SendDraftTask.performLocal without @draftLocalId."))
    Promise.resolve()

  performRemote: ->
    # Fetch the latest draft data to make sure we make the request with the most
    # recent draft version
    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      # The draft may have been deleted by another task. Nothing we can do.
      NylasAPI.incrementOptimisticChangeCount(Message, draft.id)
      @draft = draft
      if not draft
        return Promise.reject(new Error("We couldn't find the saved draft."))

      if draft.isSaved()
        body =
          draft_id: draft.id
          version: draft.version
      else
        body = draft.toJSON()

      return @_send(body)

  # Returns a promise which resolves when the draft is sent. There are several
  # failure cases where this method may call itself, stripping bad fields out of
  # the body. This promise only rejects when these changes have been tried.
  _send: (body) ->
    NylasAPI.makeRequest
      path: "/n/#{@draft.namespaceId}/send"
      method: 'POST'
      body: body
      returnsModel: true

    .then (json) =>
      message = (new Message).fromJSON(json)
      atom.playSound('mail_sent.ogg')
      Actions.sendDraftSuccess
        draftLocalId: @draftLocalId
        newMessage: message
      DatabaseStore.unpersistModel(@draft).then =>
        return Promise.resolve(Task.Status.Finished)

    .catch APIError, (err) =>
      NylasAPI.decrementOptimisticChangeCount(Message, @draft.id)
      if err.message?.indexOf('Invalid message public id') is 0
        body.reply_to_message_id = null
        return @_send(body)
      else if err.message?.indexOf('Invalid thread') is 0
        body.thread_id = null
        body.reply_to_message_id = null
        return @_send(body)
      else if err.statusCode in NylasAPI.PermanentErrorCodes
        msg = err.message ? "Your draft could not be sent."
        Actions.composePopoutDraft(@draftLocalId, {errorMessage: msg})
        return Promise.resolve(Task.Status.Finished)
      else
        return Promise.resolve(Task.Status.Retry)
