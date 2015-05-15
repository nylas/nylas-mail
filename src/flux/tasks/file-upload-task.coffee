fs = require 'fs'
pathUtils = require 'path'
Task = require './task'
File = require '../models/file'
Message = require '../models/message'
Actions = require '../actions'
NamespaceStore = require '../stores/namespace-store'
DatabaseStore = require '../stores/database-store'
{isTempId} = require '../models/utils'
NylasAPI = require '../inbox-api'

class FileUploadTask extends Task

  constructor: (@filePath, @messageLocalId) ->
    super
    @progress = null # The progress checking timer.

  performLocal: ->
    return Promise.reject(new Error("Must pass an absolute path to upload")) unless @filePath?.length
    return Promise.reject(new Error("Must be attached to a messageLocalId")) unless isTempId(@messageLocalId)
    Actions.uploadStateChanged @_uploadData("pending")
    Promise.resolve()

  performRemote: ->
    new Promise (resolve, reject) =>
      Actions.uploadStateChanged @_uploadData("started")

      @req = NylasAPI.makeRequest
        path: "/n/#{@_namespaceId()}/files"
        method: "POST"
        json: false
        returnsModel: true
        formData: @_formData()
        error: reject
        success: (rawResponseString) =>
          # The Inbox API returns the file json wrapped in an array.
          #
          # Since we requested `json:false` the response will come back as
          # a raw string.
          try
            json = JSON.parse(rawResponseString)
            file = (new File).fromJSON(json[0])
            Actions.uploadStateChanged @_uploadData("completed")
            @_completedNotification(file)

            clearInterval(@progress)
            @req = null
            resolve()
          catch error
            reject(error)

      @progress = setInterval =>
        Actions.uploadStateChanged(@_uploadData("progress"))
      , 250

  cleanup: ->
    super

    # If the request is still in progress, notify observers that
    # we've failed.
    if @req
      @req.abort()
      clearInterval(@progress)
      Actions.uploadStateChanged(@_uploadData("aborted"))
      setTimeout =>
        # To see the aborted state for a little bit
        Actions.fileAborted(@_uploadData("aborted"))
      , 1000

  onAPIError: (apiError) ->
    @_rollbackLocal()

  onOtherError: (otherError) ->
    @_rollbackLocal()

  onTimeoutError: ->
    # Do nothing. It could take a while.
    Promise.resolve()

  onOfflineError: (offlineError) ->
    msg = "You can't upload a file while you're offline."
    @_rollbackLocal(msg)

  _rollbackLocal: (msg) ->
    clearInterval(@progress)
    @req = null

    msg ?= "There was a problem uploading this file. Please try again later."
    Actions.postNotification({message: msg, type: "error"})
    Actions.uploadStateChanged @_uploadData("failed")

  # The `fileUploaded` action is needed to notify all other windows (like
  # composers) that the file has finished uploading.
  _completedNotification: (file) ->
    setTimeout =>
      # We need these to be two separate actions in this sequence so
      # stores (like the DrafStore) can attach the file to their objects
      # before we take action (like sending and closing the message) upon
      # upload completion
      Actions.attachFileComplete({file, @messageLocalId})
      Actions.fileUploaded(uploadData: @_uploadData("completed"))
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
