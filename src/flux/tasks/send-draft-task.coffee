_ = require 'underscore'
fs = require 'fs'
path = require 'path'
Task = require './task'
Actions = require '../actions'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
{APIError} = require '../errors'
SoundRegistry = require '../../sound-registry'
DatabaseStore = require '../stores/database-store'
AccountStore = require '../stores/account-store'
BaseDraftTask = require './base-draft-task'
SyncbackMetadataTask = require './syncback-metadata-task'

module.exports =
class SendDraftTask extends BaseDraftTask

  constructor: (@draftClientId) ->
    @uploaded = []
    @draft = null
    @message = null
    super

  label: ->
    "Sending message..."

  performRemote: ->
    @refreshDraftReference()
    .then(@assertDraftValidity)
    .then(@sendMessage)
    .then (responseJSON) =>
      @message = new Message().fromJSON(responseJSON)
      @message.clientId = @draft.clientId
      @message.draft = false
      @message.clonePluginMetadataFrom(@draft)

      DatabaseStore.inTransaction (t) =>
        @refreshDraftReference().then =>
          t.persistModel(@message)

    .then(@onSuccess)
    .catch(@onError)

  assertDraftValidity: =>
    unless @draft.from[0]
      return Promise.reject(new Error("SendDraftTask - you must populate `from` before sending."))

    account = AccountStore.accountForEmail(@draft.from[0].email)
    unless account
      return Promise.reject(new Error("SendDraftTask - you can only send drafts from a configured account."))

    unless @draft.accountId is account.id
      return Promise.reject(new Error("The from address has changed since you started sending this draft. Double-check the draft and click 'Send' again."))

    if @draft.uploads and @draft.uploads.length > 0
      return Promise.reject(new Error("Files have been added since you started sending this draft. Double-check the draft and click 'Send' again.."))

    return Promise.resolve()

  # This function returns a promise that resolves to the draft when the draft has
  # been sent successfully.
  sendMessage: =>
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
        return @sendMessage()

      # If the thread was deleted
      else if err.message?.indexOf('Invalid thread') is 0
        @draft.threadId = null
        @draft.replyToMessageId = null
        return @sendMessage()

      else
        return Promise.reject(err)

  onSuccess: =>
    # Queue a task to save metadata on the message
    @message.pluginMetadata.forEach((m)=>
      task = new SyncbackMetadataTask(@message.clientId, @message.constructor.name, m.pluginId)
      Actions.queueTask(task)
    )

    Actions.sendDraftSuccess(message: @message, messageClientId: @message.clientId)
    NylasAPI.makeDraftDeletionRequest(@draft)

    # Play the sending sound
    if NylasEnv.config.get("core.sending.sounds")
      SoundRegistry.playSound('send')

    return Promise.resolve(Task.Status.Success)

  onError: (err) =>
    if err instanceof BaseDraftTask.DraftNotFoundError
      return Promise.resolve(Task.Status.Continue)

    message = err.message

    if err instanceof APIError
      if err.statusCode not in NylasAPI.PermanentErrorCodes
        return Promise.resolve(Task.Status.Retry)

      message = "Sorry, this message could not be sent. Please try again, and make sure your message is addressed correctly and is not too large."
      if err.statusCode is 402 and err.body.message
        if err.body.message.indexOf('at least one recipient') isnt -1
          message = "This message could not be delivered to at least one recipient. (Note: other recipients may have received this message - you should check Sent Mail before re-sending this message.)"
        else
          message = "Sorry, this message could not be sent because it was rejected by your mail provider. (#{err.body.message})"
          if err.body.server_error
            message += "\n\n" + err.body.server_error

    Actions.draftSendingFailed
      threadId: @draft.threadId
      draftClientId: @draft.clientId,
      errorMessage: message
    NylasEnv.reportError(err)
    return Promise.resolve([Task.Status.Failed, err])
