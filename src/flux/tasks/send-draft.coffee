{isTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
Message = require '../models/message'
Task = require './task'
TaskQueue = require '../stores/task-queue'
SyncbackDraftTask = require './syncback-draft'
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
    other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId

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
      @draft = draft
      if not draft
        return Promise.reject(new Error("We couldn't find the saved draft."))

      if draft.isSaved()
        body =
          draft_id: draft.id
          version: draft.version
      else
        # Pass joined:true so the draft body is included
        body = draft.toJSON(joined: true)

      return @_performRemoteSend(body)

  # Returns a promise which resolves when the draft is sent. There are several
  # failure cases where this method may call itself, stripping bad fields out of
  # the body. This promise only rejects when these changes have been tried.
  _performRemoteSend: (body) ->
    @_performRemoteAPIRequest(body)
    .then (json) =>
      message = (new Message).fromJSON(json)
      atom.playSound('mail_sent.ogg')
      Actions.sendDraftSuccess
        draftLocalId: @draftLocalId
        newMessage: message
      return DatabaseStore.unpersistModel(@draft)

    .catch (err) =>
      if err.message?.indexOf('Invalid message public id') is 0
        body.reply_to_message_id = null
        return @_performRemoteSend(body)
      else if err.message?.indexOf('Invalid thread') is 0
        body.thread_id = null
        body.reply_to_message_id = null
        return @_performRemoteSend(body)
      else
        return Promise.reject(err)

  _performRemoteAPIRequest: (body) ->
    new Promise (resolve, reject) =>
      NylasAPI.makeRequest
        path: "/n/#{@draft.namespaceId}/send"
        method: 'POST'
        body: body
        returnsModel: true
        success: resolve
        error: reject

  onAPIError: (apiError) ->
    msg = apiError.message ? "Our server is having problems. Your message has not been sent."
    @_notifyError(msg)

  onOtherError: ->
    msg = "We had a serious issue while sending. Your message has not been sent."
    @_notifyError(msg)

  onTimeoutError: ->
    msg = "The server is taking an abnormally long time to respond. Your message has not been sent."
    @_notifyError(msg)

  onOfflineError: ->
    msg = "You are offline. Your message has NOT been sent. Please send your message when you come back online."
    @_notifyError(msg)
    # For sending draft, we don't send when we come back online.
    Actions.dequeueTask(@)

  _notifyError: (msg) ->
    @notifyErrorMessage(msg)
    if @fromPopout
      Actions.composePopoutDraft(@draftLocalId, {errorMessage: msg})
