_ = require 'underscore'
{isTempId, generateTempId} = require '../models/utils'

Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
NylasAPI = require '../nylas-api'

Task = require './task'
{APIError} = require '../errors'
Message = require '../models/message'

FileUploadTask = require './file-upload-task'

# MutateDraftTask

module.exports =
class SyncbackDraftTask extends Task

  constructor: (@draftLocalId) ->
    super

  shouldDequeueOtherTask: (other) ->
    other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId and other.creationDate < @creationDate

  shouldWaitForTask: (other) ->
    other instanceof SyncbackDraftTask and other.draftLocalId is @draftLocalId and other.creationDate < @creationDate

  performLocal: ->
    # SyncbackDraftTask does not do anything locally. You should persist your changes
    # to the local database directly or using a DraftStoreProxy, and then queue a
    # SyncbackDraftTask to send those changes to the server.
    if not @draftLocalId
      errMsg = "Attempt to call SyncbackDraftTask.performLocal without @draftLocalId"
      return Promise.reject(new Error(errMsg))
    Promise.resolve()

  performRemote: ->
    @getLatestLocalDraft().then (draft) =>
      # The draft may have been deleted by another task. Nothing we can do.
      return Promise.resolve() unless draft

      if draft.isSaved()
        path = "/n/#{draft.namespaceId}/drafts/#{draft.id}"
        method = 'PUT'
      else
        path = "/n/#{draft.namespaceId}/drafts"
        method = 'POST'

      payload = draft.toJSON()
      @submittedBody = payload.body
      delete payload['from']

      NylasAPI.makeRequest
        path: path
        method: method
        body: payload
        returnsModel: false

      .then (json) =>
        # Important: There could be a significant delay between us initiating the save
        # and getting JSON back from the server. Our local copy of the draft may have
        # already changed more.
        #
        # The only fields we want to update from the server are the `id` and `version`.
        #
        # Also note that this *could* still rollback a save between the find / persist
        # below. We currently have no way of locking between processes. Maybe a
        # log-style data structure would be better suited for drafts.
        #
        @getLatestLocalDraft().then (draft) =>
          updatedDraft = draft.clone()
          updatedDraft.version = json.version
          updatedDraft.id = json.id

          if updatedDraft.id != draft.id
            DatabaseStore.swapModel(oldModel: draft, newModel: updatedDraft, localId: @draftLocalId)
          else
            DatabaseStore.persistModel(updatedDraft)

      .then =>
        return Promise.resolve(Task.Status.Finished)

      .catch APIError, (err) =>
        if err.statusCode in [400, 404, 409] and err.requestOptions.method is 'PUT'
          return @disassociateFromRemoteID().then =>
            Promise.resolve(Task.Status.Retry)

        if err.statusCode in NylasAPI.PermanentErrorCodes
          return Promise.resolve(Task.Status.Finished)

        return Promise.resolve(Task.Status.Retry)

  getLatestLocalDraft: ->
    DatabaseStore.findByLocalId(Message, @draftLocalId)

  disassociateFromRemoteID: ->
    @getLatestLocalDraft().then (draft) =>
      return Promise.resolve() unless draft
      newDraft = new Message(draft)
      newDraft.id = generateTempId()
      DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId)
