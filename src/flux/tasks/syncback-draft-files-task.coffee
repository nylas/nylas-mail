_ = require 'underscore'
fs = require 'fs'
path = require 'path'

Task = require './task'
Actions = require '../actions'
{APIError} = require '../errors'
File = require '../models/file'
NylasAPI = require '../nylas-api'
Message = require '../models/message'
BaseDraftTask = require './base-draft-task'
DatabaseStore = require '../stores/database-store'
MultiRequestProgressMonitor = require '../../multi-request-progress-monitor'

module.exports =
class SyncbackDraftFilesTask extends BaseDraftTask

  constructor: (@draftClientId) ->
    super(@draftClientId)
    @_appliedUploads = null
    @_appliedFiles = null

  label: ->
    "Uploading attachments..."

  performRemote: ->
    @refreshDraftReference()
    .then(@uploadAttachments)
    .then(@applyChangesToDraft)
    .thenReturn(Task.Status.Success)
    .catch (err) =>
      if err instanceof BaseDraftTask.DraftNotFoundError
        return Promise.resolve(Task.Status.Continue)
      if err instanceof APIError and not (err.statusCode in NylasAPI.PermanentErrorCodes)
        return Promise.resolve(Task.Status.Retry)
      return Promise.resolve([Task.Status.Failed, err])

  uploadAttachments: =>
    @_attachmentUploadsMonitor = new MultiRequestProgressMonitor()
    Object.defineProperty(@, 'progress', {
      configurable: true,
      enumerable: true,
      get: => @_attachmentUploadsMonitor.value()
    })

    uploaded = [].concat(@draft.uploads)
    Promise.all(uploaded.map(@uploadAttachment)).then (files) =>
      # Note: We don't actually delete uploaded files until send completes,
      # because it's possible for the app to quit without saving state and
      # need to re-upload the file.
      @_appliedUploads = uploaded
      @_appliedFiles = files

  uploadAttachment: (upload) =>
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
      Promise.resolve(file)

  applyChangesToDraft: =>
    DatabaseStore.inTransaction (t) =>
      @refreshDraftReference().then =>
        @draft.files = @draft.files.concat(@_appliedFiles)
        if @draft.uploads instanceof Array
          uploadedPaths = @_appliedUploads.map (upload) => upload.targetPath
          @draft.uploads = @draft.uploads.filter (upload) =>
            upload.targetPath not in uploadedPaths
        t.persistModel(@draft)
