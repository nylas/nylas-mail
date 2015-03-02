_ = require 'underscore-plus'
{isTempId, generateTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'

Task = require './task'
Message = require '../models/message'

FileUploadTask = require './file-upload-task'

# MutateDraftTask

module.exports =
class SyncbackDraftTask extends Task

  constructor: (@draftLocalId) ->
    super
    @_saveAttempts = 0

  shouldDequeueOtherTask: (other) ->
    other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId and other.creationDate < @creationDate

  shouldWaitForTask: (other) ->
    other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId and other.creationDate < @creationDate

 performLocal: ->
  # SyncbackDraftTask does not do anything locally. You should persist your changes
  # to the local database directly or using a DraftStoreProxy, and then queue a
  # SyncbackDraftTask to send those changes to the server.
  if not @draftLocalId?
    errMsg = "Attempt to call FileUploadTask.performLocal without @draftLocalId"
    Promise.reject(new Error(errMsg))
  else
    Promise.resolve()

  performRemote: ->
    new Promise (resolve, reject) =>
      DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
        # The draft may have been deleted by another task. Nothing we can do.
        return resolve() unless draft

        if draft.isSaved()
          path = "/n/#{draft.namespaceId}/drafts/#{draft.id}"
          method = 'PUT'
        else
          path = "/n/#{draft.namespaceId}/drafts"
          method = 'POST'

        body = draft.toJSON()
        delete body['from']

        initialId = draft.id

        @_saveAttempts += 1
        atom.inbox.makeRequest
          path: path
          method: method
          body: body
          returnsModel: false
          success: (json) =>
            if json.id != initialId
              newDraft = (new Message).fromJSON(json)
              DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId).then(resolve)
            else
              DatabaseStore.persistModel(draft).then(resolve)
          error: reject

  onAPIError: (apiError) ->
    # If we get a 404 from the server this might mean that the
    # draft has been deleted from underneath us. We should retry
    # again. Before we can retry we need to set the ID to a
    # localID so that the next time this fires the model will
    # trigger a POST instead of a PUT
    if apiError.statusCode is 404
      msg = "It looks like the draft you're working on got deleted from underneath you. We're creating a new draft and saving your work."
      @_retrySaveAsNewDraft(msg)
    else
      if @_saveAttempts <= 1
        msg = "We had a problem with the server. We're going to try and save your draft again."
        @_retrySaveToExistingDraft(msg)
      else
        msg = "We're continuing to have issues saving your draft. It will be saved locally, but is failing to save on the server."
        @notifyErrorMessage(msg)

  onOtherError: ->
    msg = "We had a serious issue trying to save your draft. Please copy the text out of the composer and try again later."
    @notifyErrorMessage(msg)

  onTimeoutError: ->
    if @_saveAttempts <= 1
      msg = "The server is taking an abnormally long time to respond. We're going to try and save your changes again."
      @_retrySaveToExistingDraft(msg)
    else
      msg = "We're continuing to have issues saving your draft. It will be saved locally, but is failing to save on the server."
      @notifyErrorMessage(msg)

  onOfflineError: ->
    msg = "WARNING: You are offline. Your edits are being saved locally. They will save to the server when you come back online"
    @notifyErrorMessage(msg)

  _retrySaveAsNewDraft: (msg) ->
    TaskQueue = require '../stores/task-queue'
    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      if not draft?
        console.log "Couldn't find draft!", @draftLocalId
        @_onOtherError()

      newJSON = _.clone(draft.toJSON())
      newJSON.id = generateTempId() unless isTempId(draft.id)
      newDraft = (new Message).fromJSON(newJSON)
      DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId).then =>
        TaskQueue.enqueue @

    @notifyErrorMessage(msg)

  _retrySaveToExistingDraft: (msg) ->
    TaskQueue = require '../stores/task-queue'
    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      if not draft?
        console.log "Couldn't find draft!", @draftLocalId
        @_onOtherError()
      TaskQueue.enqueue @

    @notifyErrorMessage(msg)

