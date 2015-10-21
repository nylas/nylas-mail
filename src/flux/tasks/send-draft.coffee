Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
Message = require '../models/message'
{APIError} = require '../errors'
Task = require './task'
TaskQueue = require '../stores/task-queue'
SyncbackDraftTask = require './syncback-draft'
FileUploadTask = require './file-upload-task'
NylasAPI = require '../nylas-api'
SoundRegistry = require '../../sound-registry'

module.exports =
class SendDraftTask extends Task

  constructor: (@draftClientId, {@fromPopout}={}) ->
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draftClientId is @draftClientId

  isDependentTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftClientId is @draftClientId) or
    (other instanceof FileUploadTask and other.messageClientId is @draftClientId)

  onDependentTaskError: (task, err) ->
    if task instanceof SyncbackDraftTask
      msg = "Your message could not be sent because we could not save your draft. Please check your network connection and try again soon."
    else if task instanceof FileUploadTask
      msg = "Your message could not be sent because a file failed to upload. Please try re-uploading your file and try again."
    @_notifyUserOfError(msg) if msg

  performLocal: ->
    # When we send drafts, we don't update anything in the app until
    # it actually succeeds. We don't want users to think messages have
    # already sent when they haven't!
    if not @draftClientId
      return Promise.reject(new Error("Attempt to call SendDraftTask.performLocal without @draftClientId."))
    Promise.resolve()

  performRemote: ->
    # Fetch the latest draft data to make sure we make the request with the most
    # recent draft version
    DatabaseStore.findBy(Message, clientId: @draftClientId).include(Message.attributes.body).then (draft) =>
      # The draft may have been deleted by another task. Nothing we can do.
      @draft = draft
      if not draft
        return Promise.reject(new Error("We couldn't find the saved draft."))

      # Just before sending we ask the {DraftStoreProxy} to commit its
      # changes. This will fire a {SyncbackDraftTask}. Since we will be
      # sending the draft by its serverId, we must be ABSOLUTELY sure that
      # the {SyncbackDraftTask} succeeded otherwise we will send an
      # incomplete or obsolete message.
      if draft.serverId
        body =
          draft_id: draft.serverId
          version: draft.version
      else
        body = draft.toJSON()

      return @_send(body)

  # Returns a promise which resolves when the draft is sent. There are several
  # failure cases where this method may call itself, stripping bad fields out of
  # the body. This promise only rejects when these changes have been tried.
  _send: (body) ->
    NylasAPI.makeRequest
      path: "/send"
      accountId: @draft.accountId
      method: 'POST'
      body: body
      timeout: 1000 * 60 * 5 # We cannot hang up a send - won't know if it sent
      returnsModel: false

    .then (json) =>
      # The JSON returned from the server will be the new Message.
      #
      # Our old draft may or may not have a serverId. We update the draft
      # with whatever the server returned (which includes a serverId).
      #
      # We then save the model again (keyed by its clientId) to indicate
      # that it is no longer a draft, but rather a Message (draft: false)
      # with a valid serverId.
      @draft = @draft.clone().fromJSON(json)
      @draft.draft = false
      DatabaseStore.persistModel(@draft).then =>
        if atom.config.get("core.sending.sounds")
          SoundRegistry.playSound('send')
        Actions.sendDraftSuccess
          draftClientId: @draftClientId
          newMessage: @draft

        return Promise.resolve(Task.Status.Success)
      .catch @_permanentError

    .catch APIError, (err) =>
      if err.message?.indexOf('Invalid message public id') is 0
        body.reply_to_message_id = null
        return @_send(body)
      else if err.message?.indexOf('Invalid thread') is 0
        body.thread_id = null
        body.reply_to_message_id = null
        return @_send(body)
      else if err.statusCode is 500
        msg = "Your message could not be sent at this time. Please try again soon."
        return @_permanentError(err, msg)
      else if err.statusCode in [400, 404]
        msg = "Your message could not be sent at this time. Please try again soon."
        atom.emitError(new Error("Sending a message responded with #{err.statusCode}!"))
        return @_permanentError(err, msg)
      else if err.statusCode is NylasAPI.TimeoutErrorCode
        msg = "We lost internet connection just as we were trying to send your message! Please wait a little bit to see if it went through. If not, check your internet connection and try sending again."
        return @_permanentError(err, msg)
      else
        return Promise.resolve(Task.Status.Retry)

  _permanentError: (err, msg) =>
    @_notifyUserOfError(msg)

    return Promise.resolve([Task.Status.Failed, err])

  _notifyUserOfError: (msg) =>
    if @fromPopout
      Actions.composePopoutDraft(@draftClientId, {errorMessage: msg})
    else
      Actions.draftSendingFailed({draftClientId: @draftClientId, errorMessage: msg})
