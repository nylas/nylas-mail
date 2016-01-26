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

  add: (filepath, request) =>
    @_requests[filepath] = request
    @_expected[filepath] = fs.statSync(filepath)["size"] ? 0

  remove: (filepath) =>
    delete @_requests[filepath]
    delete @_expected[filepath]

  progress: =>
    sent = 0
    expected = 0
    for filepath, req of @_requests
      sent += @req?.req?.connection?._bytesDispatched ? 0
      expected += @_expected[filepath]

    return sent / expected

module.exports =
class SendDraftTask extends Task

  constructor: (@draft, @attachmentPaths) ->
    @_progress = new MultiRequestProgressMonitor()
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draft.clientId is @draft.clientId

  performLocal: ->
    return Promise.reject(new Error("SendDraftTask must be provided a draft.")) unless @draft
    Promise.resolve()

  performRemote: ->
    @_uploadAttachments()
    .then(@_sendAndCreateMessage)
    .then(@_deleteDraft)
    .then(@_onSuccess)
    .catch(@_onError)

  _uploadAttachments: =>
    Promise.all @attachmentPaths.map (filepath) =>
      NylasAPI.makeRequest
        path: "/files"
        accountId: @draft.accountId
        method: "POST"
        json: false
        formData:
          file: # Must be named `file` as per the Nylas API spec
            value: fs.createReadStream(filepath)
            options:
              filename: path.basename(filepath)
        started: (req) =>
          @_progress.add(filepath, req)
        timeout: 20 * 60 * 1000
      .finally =>
        @_progress.remove(filepath)
      .then (file) =>
        @draft.files.push(file)

  _sendAndCreateMessage: =>
    NylasAPI.makeRequest
      path: "/send"
      accountId: @draft.accountId
      method: 'POST'
      body: draftModel.toJSON()
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
    # Return if the draft hasn't been saved server-side (has no `serverId`).
    return Promise.resolve() unless @draft.serverId

    NylasAPI.makeRequest
      path: "/drafts/#{@draft.serverId}"
      accountId: @draft.accountId
      method: "DELETE"
      body:
        version: @draft.version
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
    @attachmentPaths.forEach(fs.unlink)

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
