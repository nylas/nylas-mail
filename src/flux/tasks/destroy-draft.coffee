Task = require './task'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'

SyncbackDraftTask = require './syncback-draft'
SendDraftTask = require './send-draft'
FileUploadTask = require './file-upload-task'

module.exports =
class DestroyDraftTask extends Task
  constructor: (@draftLocalId) -> super

  shouldDequeueOtherTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId) or
    (other instanceof SendDraftTask and other.draftLocalId is @draftLocalId) or
    (other instanceof FileUploadTask and other.draftLocalId is @draftLocalId)

  shouldWaitForTask: (other) ->
    (other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId)

  performLocal: ->
    new Promise (resolve, reject) =>
      unless @draftLocalId?
        return reject(new Error("Attempt to call DestroyDraftTask.performLocal without @draftLocalId"))

      DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
        @draft = draft
        DatabaseStore.unpersistModel(draft).then(resolve)

  performRemote: ->
    new Promise (resolve, reject) =>
      # We don't need to do anything if we weren't able to find the draft
      # when we performed locally, or if the draft has never been synced to
      # the server (id is still self-assigned)
      return resolve() unless @draft
      return resolve() unless @draft.isSaved()

      atom.inbox.makeRequest
        path: "/n/#{@draft.namespaceId}/drafts/#{@draft.id}"
        method: "DELETE"
        body:
          version: @draft.version
        returnsModel: false
        success: (args...) =>
          Actions.destroyDraftSuccess(@draftLocalId)
          resolve(args...)
        error: reject

  onAPIError: (apiError) ->
    inboxMsg = apiError.body?.message ? ""
    if apiError.statusCode is 404
      # Draft has already been deleted, this is not really an error
      return true
    else if inboxMsg.indexOf("is not a draft") >= 0
      # Draft has been sent, and can't be deleted. Not much we can
      # do but finish
      return true
    else
      Actions.destroyDraftError(@draftLocalId)
      @_rollbackLocal()

  onOtherError: -> Promise.resolve()
  onTimeoutError: -> Promise.resolve()
  onOfflineError: -> Promise.resolve()

  _rollbackLocal: (msg) ->
    msg ?= "Unable to delete this draft. Restoring..."
    Actions.postNotification({message: msg, type: "error"})
    DatabaseStore.persistModel(@draft) if @draft?
