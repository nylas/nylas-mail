_ = require 'underscore-plus'
{isTempId, generateTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'

Task = require './task'
Message = require '../models/message'

FileUploadTask = require './file-upload-task'

module.exports =
class SaveDraftTask extends Task

  constructor: (@draftLocalId, @changes={}, {@localOnly}={}) ->
    @_saveAttempts = 0
    @queuedAt = Date.now()
    super

  # We also don't want to cancel any tasks that have a later timestamp
  # creation than us. It's possible, because of retries, that tasks could
  # get re-pushed onto the queue out of order.
  shouldDequeueOtherTask: (other) ->
    other instanceof SaveDraftTask and
    other.draftLocalId is @draftLocalId and
    other.queuedAt < @queuedAt # other is an older task.

  shouldWaitForTask: (other) ->
    other instanceof FileUploadTask and other.draftLocalId is @draftLocalId

  performLocal: -> new Promise (resolve, reject) =>
    if not @draftLocalId?
      errMsg = "Attempt to call FileUploadTask.performLocal without @draftLocalId"
      return reject(new Error(errMsg))

    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      if not draft?
        # This can happen if a save draft task is queued after it has been
        # destroyed. Nothing we can really do about it, so ignore this.
        resolve()
      else if _.size(@changes) is 0
        resolve()
      else
        updatedDraft = @_applyChangesToDraft(draft, @changes)
        DatabaseStore.persistModel(updatedDraft).then(resolve)
    .catch(reject)

  performRemote: ->
    if @localOnly then return Promise.resolve()

    new Promise (resolve, reject) =>
      # Fetch the latest draft data to make sure we make the request with the most
      # recent draft version
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
            newDraft = (new Message).fromJSON(json)
            if newDraft.id != initialId
              DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId).then(resolve)
            else
              DatabaseStore.persistModel(newDraft).then(resolve)
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

  _applyChangesToDraft: (draft, changes={}) ->
    for key, definition of draft.attributes()
      draft[key] = changes[key] if changes[key]?
    return draft
