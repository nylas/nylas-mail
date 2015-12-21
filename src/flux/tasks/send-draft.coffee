_ = require 'underscore'
Task = require './task'
Actions = require '../actions'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
TaskQueue = require '../stores/task-queue'
{APIError} = require '../errors'
SoundRegistry = require '../../sound-registry'
DatabaseStore = require '../stores/database-store'
FileUploadTask = require './file-upload-task'
class NotFoundError extends Error
  constructor: -> super

module.exports =
class SendDraftTask extends Task

  constructor: (@draftClientId, {@fromPopout}={}) ->
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draftClientId is @draftClientId

  isDependentTask: (other) ->
    (other instanceof FileUploadTask and other.messageClientId is @draftClientId)

  onDependentTaskError: (task, err) ->
    if task instanceof FileUploadTask
      msg = "Your message could not be sent because a file failed to upload. Please try re-uploading your file and try again."
    @_notifyUserOfError(msg) if msg

  performLocal: ->
    if not @draftClientId
      return Promise.reject(new Error("Attempt to call SendDraftTask.performLocal without @draftClientId."))

    # It's possible that between a user requesting the draft to send and
    # the queue eventualy getting around to the `performLocal`, the Draft
    # object may have been deleted. This could be caused by a user
    # accidentally hitting "delete" on the same draft in another popout
    # window. If this happens, `performRemote` will fail when we try and
    # look up the draft by its clientId.
    #
    # In this scenario, we don't want to send, but want to restore the
    # draft and notify the user to try again. In order to safely do this
    # we need to keep a backup to restore.
    DatabaseStore.findBy(Message, clientId: @draftClientId).then (draftModel) =>
      @backupDraft = draftModel.clone()

  performRemote: ->
    @_fetchLatestDraft()
    .then(@_makeSendRequest)
    .then(@_saveNewMessage)
    .then(@_deleteRemoteDraft)
    .then(@_notifySuccess)
    .catch(@_onError)

  _fetchLatestDraft: ->
    DatabaseStore.findBy(Message, clientId: @draftClientId).then (draftModel) =>
      @draftAccountId = draftModel.accountId
      @draftServerId = draftModel.serverId
      @draftVersion = draftModel.version
      if not draftModel
        throw new NotFoundError("#{@draftClientId} not found")
      return draftModel
    .catch (err) =>
      throw new NotFoundError("#{@draftClientId} not found")

  _makeSendRequest: (draftModel) =>
    NylasAPI.makeRequest
      path: "/send"
      accountId: @draftAccountId
      method: 'POST'
      body: draftModel.toJSON()
      timeout: 1000 * 60 * 5 # We cannot hang up a send - won't know if it sent
      returnsModel: false
    .catch (err) =>
      tryAgainDraft = draftModel.clone()
      # If the message you're "replying to" were deleted
      if err.message?.indexOf('Invalid message public id') is 0
        tryAgainDraft.replyToMessageId = null
        return @_makeSendRequest(tryAgainDraft)
      else if err.message?.indexOf('Invalid thread') is 0
        tryAgainDraft.threadId = null
        tryAgainDraft.replyToMessageId = null
        return @_makeSendRequest(tryAgainDraft)
      else return Promise.reject(err)

  # The JSON returned from the server will be the new Message.
  #
  # Our old draft may or may not have a serverId. We update the draft with
  # whatever the server returned (which includes a serverId).
  #
  # We then save the model again (keyed by its client_id) to indicate that
  # it is no longer a draft, but rather a Message (draft: false) with a
  # valid serverId.
  _saveNewMessage: (newMessageJSON) =>
    @message = new Message().fromJSON(newMessageJSON)
    @message.clientId = @draftClientId
    @message.draft = false
    return DatabaseStore.inTransaction (t) =>
      t.persistModel(@message)

  # We DON'T need to delete the local draft because we actually transmute
  # it into a {Message} by setting the `draft` flat to `true` in the
  # `_saveNewMessage` method.
  #
  # We DO, however, need to make sure that the remote draft has been
  # cleaned up.
  #
  # Not all drafts will have a server component. Only those that have been
  # persisted by a {SyncbackDraftTask} will have a `serverId`.
  _deleteRemoteDraft: =>
    return Promise.resolve() unless @draftServerId
    NylasAPI.makeRequest
      path: "/drafts/#{@draftServerId}"
      accountId: @draftAccountId
      method: "DELETE"
      body: version: @draftVersion
      returnsModel: false
    .catch APIError, (err) =>
      # If the draft failed to delete remotely, we don't really care. It
      # shouldn't stop the send draft task from continuing.
      console.error("Deleting the draft remotely failed", err)

  _notifySuccess: =>
    Actions.sendDraftSuccess
      draftClientId: @draftClientId
      newMessage: @message
    if NylasEnv.config.get("core.sending.sounds")
      SoundRegistry.playSound('send')
    return Task.Status.Success

  _onError: (err) =>
    msg = "Your message could not be sent at this time. Please try again soon."
    if err instanceof NotFoundError
      msg = "The draft you are trying to send has been deleted. We have restored your draft. Please try and send again."
      DatabaseStore.inTransaction (t) =>
        t.persistModel(@backupDraft)
      .then =>
        return @_permanentError(err, msg)
    else if err instanceof APIError
      if err.statusCode is 500
        return @_permanentError(err, msg)
      else if err.statusCode in [400, 404]
        NylasEnv.emitError(new Error("Sending a message responded with #{err.statusCode}!"))
        return @_permanentError(err, msg)
      else if err.statusCode is NylasAPI.TimeoutErrorCode
        msg = "We lost internet connection just as we were trying to send your message! Please wait a little bit to see if it went through. If not, check your internet connection and try sending again."
        return @_permanentError(err, msg)
      else
        return Promise.resolve(Task.Status.Retry)
    else
      NylasEnv.emitError(err)
      return @_permanentError(err, msg)

  _permanentError: (err, msg) =>
    @_notifyUserOfError(msg)

    return Promise.resolve([Task.Status.Failed, err])

  _notifyUserOfError: (msg) =>
    if @fromPopout
      Actions.composePopoutDraft(@draftClientId, {errorMessage: msg})
    else
      Actions.draftSendingFailed({draftClientId: @draftClientId, errorMessage: msg})
