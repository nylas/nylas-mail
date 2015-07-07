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
      errMsg = "Attempt to call FileUploadTask.performLocal without @draftLocalId"
      return Promise.reject(new Error(errMsg))
    Promise.resolve()

  performRemote: ->
    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      # The draft may have been deleted by another task. Nothing we can do.
      return Promise.resolve() unless draft

      if draft.isSaved()
        path = "/n/#{draft.namespaceId}/drafts/#{draft.id}"
        method = 'PUT'
      else
        path = "/n/#{draft.namespaceId}/drafts"
        method = 'POST'

      body = draft.toJSON()
      delete body['from']

      initialId = draft.id

      NylasAPI.makeRequest
        path: path
        method: method
        body: body
        returnsModel: false

      .then (json) =>
        if json.id != initialId
          newDraft = (new Message).fromJSON(json)
          DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId)
        else
          DatabaseStore.persistModel(draft)

      .catch APIError, (err) =>
        if err.statusCode in NylasAPI.PermanentErrorCodes
          if err.requestOptions.method is 'PUT'
            return @disassociateFromRemoteID().then =>
              Promise.resolve(Task.Status.Retry)
          else
            return Promise.resolve(Task.Status.Finished)
        else
          return Promise.resolve(Task.Status.Retry)

  disassociateFromRemoteID: ->
    DatabaseStore.findByLocalId(Message, @draftLocalId).then (draft) =>
      return Promise.resolve() unless draft
      newJSON = _.clone(draft.toJSON())
      newJSON.id = generateTempId() unless isTempId(draft.id)
      newDraft = (new Message).fromJSON(newJSON)
      DatabaseStore.swapModel(oldModel: draft, newModel: newDraft, localId: @draftLocalId)
