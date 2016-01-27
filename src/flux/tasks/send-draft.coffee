_ = require 'underscore'
fs = require 'fs'
path = require 'path'
Task = require './task'
Actions = require '../actions'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
TaskQueue = require '../stores/task-queue'
{APIError} = require '../errors'
SoundRegistry = require '../../sound-registry'
DatabaseStore = require '../stores/database-store'

class MultiRequestProgressMonitor

  constructor: ->
    @_requests = {}
    @_expected = {}

  add: (filepath, filesize, request) =>
    @_requests[filepath] = request
    @_expected[filepath] = filesize ? fs.statSync(filepath)["size"] ? 0

  remove: (filepath) =>
    delete @_requests[filepath]
    delete @_expected[filepath]

  value: =>
    sent = 0
    expected = 1
    for filepath, req of @_requests
      sent += @req?.req?.connection?._bytesDispatched ? 0
      expected += @_expected[filepath]

    return sent / expected

module.exports =
class SendDraftTask extends Task

  constructor: (@draft, @uploads) ->
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draft.clientId is @draft.clientId

  performLocal: ->
    unless @draft and @draft instanceof Message
      return Promise.reject(new Error("SendDraftTask - must be provided a draft."))
    unless @uploads and @uploads instanceof Array
      return Promise.reject(new Error("SendDraftTask - must be provided an array of uploads."))

    account = AccountStore.accountForEmail(@draft.from[0])
    unless account
      return Promise.reject(new Error("SendDraftTask - you can only send drafts from a configured account."))

    if @draft.serverId
      @deleteAfterSending =
        accountId: @draft.accountId
        serverId: @draft.serverId
        version: @draft.version

    if account.id isnt @draft.accountId
      @draft.accountId = account.id
      @draft.replyToMessageId = null
      @draft.threadId = null

    Promise.resolve()

  performRemote: ->
    @_uploadAttachments()
    .then(@_sendAndCreateMessage)
    .then(@_deleteRemoteDraft)
    .then(@_onSuccess)
    .catch(@_onError)

  _uploadAttachments: =>
    progress = new MultiRequestProgressMonitor()
    Object.defineProperty(@, 'progress', { get: -> progress.value() })

    Promise.all @uploads.map (upload) =>
      {targetPath, size} = upload

      formData =
        file: # Must be named `file` as per the Nylas API spec
          value: fs.createReadStream(targetPath)
          options:
            filename: path.basename(targetPath)

      NylasAPI.makeRequest
        path: "/files"
        accountId: @draft.accountId
        method: "POST"
        json: false
        formData: formData
        started: (req) =>
          progress.add(targetPath, size, req)
        timeout: 20 * 60 * 1000
      .finally =>
        progress.remove(targetPath)
      .then (file) =>
        @uploads.splice(@uploads.indexOf(upload), 1)
        @draft.files.push(file)

  _sendAndCreateMessage: =>
    NylasAPI.makeRequest
      path: "/send"
      accountId: @draft.accountId
      method: 'POST'
      body: @draft.toJSON()
      timeout: 1000 * 60 * 5 # We cannot hang up a send - won't know if it sent
      returnsModel: false

    .catch (err) =>
      # If the message you're "replying to" were deleted
      if err.message?.indexOf('Invalid message public id') is 0
        @draft.replyToMessageId = null
        return @_sendAndCreateMessage()

      # If the thread was deleted
      else if err.message?.indexOf('Invalid thread') is 0
        @draft.threadId = null
        @draft.replyToMessageId = null
        return @_sendAndCreateMessage()

      else
        return Promise.reject(err)

    .then (newMessageJSON) =>
      @message = new Message().fromJSON(newMessageJSON)
      @message.clientId = @draft.clientId
      @message.draft = false
      DatabaseStore.inTransaction (t) =>
        t.persistModel(@message)

  # We DON'T need to delete the local draft because we turn it into a message
  # by writing the new message into the database with the same clientId.
  #
  # We DO, need to make sure that the remote draft has been cleaned up.
  #
  _deleteRemoteDraft: =>
    return Promise.resolve() unless @deleteAfterSending
    {accountId, version, serverId} = @deleteAfterSending

    NylasAPI.makeRequest
      path: "/drafts/#{serverId}"
      accountId: accountId
      method: "DELETE"
      body: {version}
      returnsModel: false
    .catch APIError, (err) =>
      # If the draft failed to delete remotely, we don't really care. It
      # shouldn't stop the send draft task from continuing.
      Promise.resolve()

  _onSuccess: =>
    Actions.sendDraftSuccess
      draftClientId: @draftClientId
      newMessage: @message

    # Play the sending sound
    if NylasEnv.config.get("core.sending.sounds")
      SoundRegistry.playSound('send')

    # Remove attachments we were waiting to upload
    # Call the Action to do this
    for upload in @uploads
      Actions.removeFileFromUpload(upload.messageClientId, upload.id)

    return Promise.resolve(Task.Status.Success)

  _onError: (err) =>
    msg = "Your message could not be sent at this time. Please try again soon."
    if err instanceof APIError and err.statusCode is NylasAPI.TimeoutErrorCode
      msg = "We lost internet connection just as we were trying to send your message! Please wait a little bit to see if it went through. If not, check your internet connection and try sending again."

    recoverableStatusCodes = [400, 404, 500, NylasAPI.TimeoutErrorCode]

    if err instanceof APIError and err.statusCode in recoverableStatusCodes
      return Promise.resolve(Task.Status.Retry)

    else
      Actions.draftSendingFailed
        threadId: @threadId
        draftClientId: @draftClientId,
        errorMessage: msg
      NylasEnv.emitError(err)
      return Promise.resolve([Task.Status.Failed, err])
