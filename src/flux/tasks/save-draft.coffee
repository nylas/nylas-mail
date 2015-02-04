_ = require 'underscore-plus'
{isTempId, generateTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'

Task = require './task'
Message = require '../models/message'

FileUploadTask = require './file-upload-task'

class SaveDraftTask extends Task

  constructor: (@draftLocalId, @changes={}, {@localOnly}={}) ->
    @queuedAt = Date.now()
    @

  # We can only cancel localOnly saves. API saves we keep.
  #
  # We also don't want to cancel any tasks that have a later timestamp
  # creation than us. It's possible, because of retries, that tasks could
  # get re-pushed onto the queue out of order.
  shouldCancelUnstartedTask: (other) ->
    other instanceof SaveDraftTask and
    other.draftLocalId is @draftLocalId and
    other.localOnly is true and
    other.queuedAt < @queuedAt # other is an older task.

  # We want to wait for SendDraftTask because it's possible that we
  # queued a SaveDraftTask (from some latent timer or something like that)
  # while the SendDraftTask was in flight. Once the SendDraftTask is done,
  # it will delete the draft from the database. The lack of the model in
  # the DB will correctly prevent any late-to-the-game SaveDraftTask from
  # executing.
  shouldWaitForTask: (other) ->
    # The task require needs to be put here otherwise we get a circular
    # reference.
    # SaveDraftTask depends on SendDraftTask
    # SendDraftTask depends on SaveDraftTask
    SendDraftTask = require './send-draft'
    other instanceof SendDraftTask and other.draftLocalId is @draftLocalId
    other instanceof FileUploadTask and other.draftLocalId is @draftLocalId

  # It's possible that in between saves, the draft was destroyed on the
  # server. Retry
  shouldRetry: (error) ->
    return true if error?.statusCode is 404
    super(error)

  performLocal: -> new Promise (resolve, reject) =>
    if not @draftLocalId?
      errMsg = "Attempt to call FileUploadTask.performLocal without @draftLocalId"
      return reject(new Error(errMsg))

    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      if not draft?
        errMsg = "Cannot persist changes to non-existent draft #{@draftLocalId}"
        reject(new Error(errMsg))
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
          error: (apiError) =>
            # If we get a 404 from the server this might mean that the
            # draft has been deleted from underneath us. We should retry
            # again. Before we can retry we need to set the ID to a
            # localID so that the next time this fires the model will
            # trigger a POST instead of a PUT
            #
            # The shouldRetry method will also detect the error as a 404
            # and retry.
            if apiError.statusCode is 404
              @_handleRetry(apiError, reject)
            else
              reject(apiError)

  _handleRetry: (apiError, reject) ->
    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      if not draft?
        # In the time since we asked the API for something, the draft has
        # been deleted. Nothing we can do now.
        msg = "The server returned an error, but the draft #{@draftLocalId} dissapeared"
        console.error(msg, apiError)
        reject(new Error(msg))
      else if isTempId(draft.id)
        msg = "The server returned an error, but the draft #{@draftLocalId} got reset to a localId"
        console.error(msg, apiError)
        reject(new Error(msg))
      else
        newJSON = _.extend({}, draft.toJSON(), id: generateTempId())
        newDraft = (new Message).fromJSON(newJSON)
        DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId).then ->
          reject(apiError)

  _applyChangesToDraft: (draft, changes={}) ->
    for key, definition of draft.attributes()
      draft[key] = changes[key] if changes[key]?
    return draft

module.exports = SaveDraftTask
