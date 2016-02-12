_ = require 'underscore'
fs = require 'fs'
path = require 'path'
Task = require './task'
Actions = require '../actions'
File = require '../models/file'
Message = require '../models/message'
{PluginMetadata} = require '../models/model-with-metadata'
NylasAPI = require '../nylas-api'
TaskQueue = require '../stores/task-queue'
{APIError} = require '../errors'
SoundRegistry = require '../../sound-registry'
DatabaseStore = require '../stores/database-store'
AccountStore = require '../stores/account-store'
SyncbackMetadataTask = require './syncback-metadata-task'

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

  requests: =>
    _.values(@_requests)

  value: =>
    sent = 0
    expected = 1
    for filepath, request of @_requests
      sent += request.req?.connection?._bytesDispatched ? 0
      expected += @_expected[filepath]

    return sent / expected

module.exports =
class SendDraftTask extends Task

  constructor: (@draft) ->
    @uploaded = []
    super

  label: ->
    "Sending draft..."

  shouldDequeueOtherTask: (other) ->
    other instanceof SendDraftTask and other.draft.clientId is @draft.clientId

  performLocal: ->
    unless @draft and @draft instanceof Message
      return Promise.reject(new Error("SendDraftTask - must be provided a draft."))
    unless @draft.uploads and @draft.uploads instanceof Array
      return Promise.reject(new Error("SendDraftTask - must be provided an array of uploads."))
    unless @draft.from[0]
      return Promise.reject(new Error("SendDraftTask - you must populate `from` before sending."))

    account = AccountStore.accountForEmail(@draft.from[0].email)
    unless account
      return Promise.reject(new Error("SendDraftTask - you can only send drafts from a configured account."))

    if account.id isnt @draft.accountId
      @draft.accountId = account.id
      delete @draft.serverId
      delete @draft.version
      delete @draft.threadId
      delete @draft.replyToMessageId

    Promise.resolve()

  performRemote: ->
    @_uploadAttachments().then =>
      return Promise.resolve(Task.Status.Continue) if @_cancelled
      @_sendAndCreateMessage()
      .then(@_deleteRemoteDraft)
      .then(@_onSuccess)
      .catch(@_onError)

  cancel: =>
    # Note that you can only cancel during the uploadAttachments phase. Once
    # we hit sendAndCreateMessage, nothing checks the cancelled bit and
    # performRemote will continue through to success.
    @_cancelled = true
    for request in @_attachmentUploadsMonitor.requests()
      request.abort()
    @

  _uploadAttachments: =>
    @_attachmentUploadsMonitor = new MultiRequestProgressMonitor()
    Object.defineProperty(@, 'progress', {
      configurable: true,
      enumerable: true,
      get: => @_attachmentUploadsMonitor.value()
    })

    Promise.all @draft.uploads.map (upload) =>
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
          @_attachmentUploadsMonitor.add(targetPath, size, req)
        timeout: 20 * 60 * 1000
      .finally =>
        @_attachmentUploadsMonitor.remove(targetPath)
      .then (rawResponseString) =>
        json = JSON.parse(rawResponseString)
        file = (new File).fromJSON(json[0])
        @uploaded.push(upload)
        @draft.uploads.splice(@draft.uploads.indexOf(upload), 1)
        @draft.files.push(file)

        # Note: We don't actually delete uploaded files until send completes,
        # because it's possible for the app to quit without saving state and
        # need to re-upload the file.

  # This function returns a promise that resolves to the draft when the draft has
  # been sent successfully.
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
      # Create new metadata objs on the message based on the existing ones in the draft
      @message.pluginMetadata = @draft.pluginMetadata.map((m)=>
        new PluginMetadata
          pluginId: m.pluginId,
          value: m.value
      );

      return DatabaseStore.inTransaction (t) =>
        DatabaseStore.findBy(Message, {clientId: @draft.clientId})
        .then (draft) =>
          t.persistModel(@message).then =>
            Promise.resolve(draft)


  # We DON'T need to delete the local draft because we turn it into a message
  # by writing the new message into the database with the same clientId.
  #
  # We DO, need to make sure that the remote draft has been cleaned up.
  #
  _deleteRemoteDraft: ({accountId, version, serverId}) =>
    return Promise.resolve() unless serverId
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
      draftClientId: @draft.clientId

    # Delete attachments from the uploads folder
    for upload in @uploaded
      Actions.attachmentUploaded(upload)

    # Queue a task to save metadata on the message
    @message.pluginMetadata.forEach((m)=>
      task = new SyncbackMetadataTask(@message.clientId, @message.constructor.name, m.pluginId)
      Actions.queueTask(task)
    )

    # Play the sending sound
    if NylasEnv.config.get("core.sending.sounds")
      SoundRegistry.playSound('send')

    return Promise.resolve(Task.Status.Success)

  _onError: (err) =>
    if err instanceof APIError and not (err.statusCode in NylasAPI.PermanentErrorCodes)
      return Promise.resolve(Task.Status.Retry)
    else
      Actions.draftSendingFailed
        threadId: @draft.threadId
        draftClientId: @draft.clientId,
        errorMessage: "Your message could not be sent. Check your network connection and try again."
      NylasEnv.reportError(err)
      return Promise.resolve([Task.Status.Failed, err])
