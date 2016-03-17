_ = require 'underscore'
fs = require 'fs'
path = require 'path'

Task = require './task'
Actions = require '../actions'
DatabaseStore = require '../stores/database-store'
TaskQueueStatusStore = require '../stores/task-queue-status-store'
MultiRequestProgressMonitor = require '../../multi-request-progress-monitor'
NylasAPI = require '../nylas-api'

BaseDraftTask = require './base-draft-task'
SyncbackMetadataTask = require './syncback-metadata-task'
{APIError} = require '../errors'

class DraftNotFoundError extends Error

module.exports =
class SyncbackDraftTask extends BaseDraftTask

  performRemote: ->
    @refreshDraftReference()
    .then =>
      if @draft.serverId
        requestPath = "/drafts/#{@draft.serverId}"
        requestMethod = 'PUT'
      else
        requestPath = "/drafts"
        requestMethod = 'POST'

      NylasAPI.makeRequest
        accountId: @draft.accountId
        path: requestPath
        method: requestMethod
        body: @draft.toJSON()
        returnsModel: false
      .then(@applyResponseToDraft)
      .thenReturn(Task.Status.Success)

    .catch (err) =>
      if err instanceof DraftNotFoundError
        return Promise.resolve(Task.Status.Continue)
      if err instanceof APIError and not (err.statusCode in NylasAPI.PermanentErrorCodes)
        return Promise.resolve(Task.Status.Retry)
      return Promise.resolve([Task.Status.Failed, err])

  applyResponseToDraft: (response) =>
    # Important: There could be a significant delay between us initiating the save
    # and getting JSON back from the server. Our local copy of the draft may have
    # already changed more.
    #
    # The only fields we want to update from the server are the `id` and `version`.
    #
    draftWasCreated = false

    DatabaseStore.inTransaction (t) =>
      @refreshDraftReference().then =>
        if @draft.serverId isnt response.id
          @draft.threadId = response.thread_id
          @draft.serverId = response.id
          draftWasCreated = true
        @draft.version = response.version
        t.persistModel(@draft)

    .then =>
      if draftWasCreated
        for {pluginId, value} in @draft.pluginMetadata
          task = new SyncbackMetadataTask(@draftClientId, @draft.constructor.name, pluginId)
          Actions.queueTask(task)
      return true
