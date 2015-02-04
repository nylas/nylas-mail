fs = require 'fs'
pathUtils = require 'path'
Task = require './task'
File = require '../models/file'
Message = require '../models/message'
Actions = require '../actions'
NamespaceStore = require '../stores/namespace-store'
DatabaseStore = require '../stores/database-store'
{isTempId} = require '../models/utils'

class FileUploadTask extends Task

  constructor: (@filePath, @messageLocalId) ->
    @progress = null # The progress checking timer.
    @

  performLocal: ->
    return Promise.reject(new Error("Must pass an absolute path to upload")) unless @filePath?.length
    return Promise.reject(new Error("Must be attached to a messageLocalId")) unless isTempId(@messageLocalId)
    Actions.uploadStateChanged @_uploadData("pending")
    Promise.resolve()

  rollbackLocal: ->
    Actions.uploadStateChanged @_uploadData("failed")

  performRemote: ->
    new Promise (resolve, reject) =>
      Actions.uploadStateChanged @_uploadData("started")

      @req = atom.inbox.makeRequest
        path: "/n/#{@_namespaceId()}/files"
        method: "POST"
        json: false
        formData: @_formData()
        success: (json) => @_onUploadSuccess(json, resolve)
        error: (apiError) =>
          clearInterval(@progress)
          reject(apiError)

      @progress = setInterval =>
        Actions.uploadStateChanged(@_uploadData("progress"))
      , 250

  abort: ->
    @req?.abort()
    clearInterval(@progress)
    Actions.uploadStateChanged(@_uploadData("aborted"))

    setTimeout =>
      Actions.fileAborted(@_uploadData("aborted"))
    , 1000 # To see the aborted state for a little bit

  _onUploadSuccess: (json, taskCallback) ->
    clearInterval(@progress)

    # The Inbox API returns the file json wrapped in an array
    file = (new File).fromJSON(json[0])

    Actions.uploadStateChanged @_uploadData("completed")

    @_completedNotification(file)

    taskCallback()

  _completedNotification: (file) ->
    setTimeout =>
      Actions.fileUploaded
        file: file
        uploadData: @_uploadData("completed")
    , 1000 # To see the success state for a little bit

  _formData: ->
    file: # Must be named `file` as per the Inbox API spec
      value: fs.createReadStream(@filePath)
      options:
        filename: @_uploadData().fileName

  # returns:
  #   messageLocalId - The localId of the message (draft) we're uploading to
  #   filePath - The full absolute local system file path
  #   fileSize - The size in bytes
  #   fileName - The basename of the file
  #   bytesUploaded - Current number of bytes uploaded
  #   state - one of "pending" "started" "progress" "completed" "aborted" "failed"
  _uploadData: (state) ->
    @_memoUploadData ?=
      messageLocalId: @messageLocalId
      filePath: @filePath
      fileSize: @_getFileSize(@filePath)
      fileName: pathUtils.basename(@filePath)
    @_memoUploadData.bytesUploaded = @_getBytesUploaded()
    @_memoUploadData.state = state if state?
    return @_memoUploadData

  _getFileSize: (path) ->
    fs.statSync(path)["size"]

  _getBytesUploaded: ->
    # https://github.com/request/request/issues/941
    # http://stackoverflow.com/questions/12098713/upload-progress-request
    @req?.req?.connection?._bytesDispatched ? 0

  _namespaceId: -> NamespaceStore.current()?.id

module.exports = FileUploadTask
