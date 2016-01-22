fs = require 'fs'
_ = require 'underscore'
crypto = require 'crypto'
pathUtils = require 'path'
Task = require './task'
{APIError} = require '../errors'
File = require '../models/file'
Message = require '../models/message'
Actions = require '../actions'
AccountStore = require '../stores/account-store'
DatabaseStore = require '../stores/database-store'
{isTempId} = require '../models/utils'
NylasAPI = require '../nylas-api'
Utils = require '../models/utils'

UploadCounter = 0

class FileUploadTask extends Task

  constructor: (@filePath, @messageClientId) ->
    super
    @_startDate = Date.now()
    @_startId = UploadCounter
    UploadCounter += 1

    @progress = null # The progress checking timer.

  performLocal: ->
    return Promise.reject(new Error("Must pass an absolute path to upload")) unless @filePath?.length
    return Promise.reject(new Error("Must be attached to a messageClientId")) unless isTempId(@messageClientId)
    Actions.uploadStateChanged @_uploadData("pending")
    Promise.resolve()

  performRemote: ->
    Actions.uploadStateChanged @_uploadData("started")

    DatabaseStore.findBy(Message, {clientId: @messageClientId}).then (draft) =>
      if not draft
        err = new Error("Can't find draft #{@messageClientId} in Database to upload file to")
        return Promise.resolve([Task.Status.Failed, err])

      @_accountId = draft.accountId

      @_makeRequest()
      .then @_performRemoteParseFile
      .then @_performRemoteAttachFile
      .then (file) =>
        Actions.uploadStateChanged @_uploadData("completed")
        Actions.fileUploaded(file: file, uploadData: @_uploadData("completed"))
        return Promise.resolve(Task.Status.Success)
      .catch APIError, (err) =>
        if err.statusCode in NylasAPI.PermanentErrorCodes
          msg = "There was a problem uploading this file. Please try again later."
          Actions.uploadStateChanged(@_uploadData("failed"))
          Actions.postNotification({message: msg, type: "error"})
          return Promise.resolve([Task.Status.Failed, err])
        else if err.statusCode is NylasAPI.CancelledErrorCode
          Actions.uploadStateChanged(@_uploadData("aborted"))
          Actions.fileAborted(@_uploadData("aborted"))
          return Promise.resolve(Task.Status.Failed)
        else
          return Promise.resolve(Task.Status.Retry)

  _makeRequest: =>
    started = (req) =>
      @req = req
      @progress = setInterval =>
        Actions.uploadStateChanged(@_uploadData("progress"))
      , 250

    cleanup = =>
      clearInterval(@progress)
      @req = null

    NylasAPI.makeRequest
      path: "/files"
      accountId: @_accountId
      method: "POST"
      json: false
      formData: @_formData()
      started: started
      timeout: 20 * 60 * 1000
    .finally(cleanup)

  _performRemoteParseFile: (rawResponseString) =>
    # The Nylas API returns the file json wrapped in an array.
    # Since we requested `json:false` the response will come back as
    # a raw string.
    json = JSON.parse(rawResponseString)
    file = (new File).fromJSON(json[0])
    Promise.resolve(file)

  _performRemoteAttachFile: (file) =>
    # The minute we know what file is associated with the upload, we need
    # to fire an Action to notify a popout window's FileUploadStore that
    # these two objects are linked. We unfortunately can't wait until
    # `_attachFileToDraft` resolves, because that will resolve after the
    # DB transaction is completed AND all of the callbacks have fired.
    # Unfortunately in the callback chain is a render method which means
    # that the upload will be left on the page for a split second before
    # we know the file has been uploaded.
    #
    # Associating the upload with the file ahead of time can let the
    # Composer know which ones to ignore when de-duping the upload/file
    # listing.
    Actions.linkFileToUpload(file: file, uploadData: @_uploadData("completed"))


    DraftStore = require '../stores/draft-store'

    DraftStore.sessionForClientId(@messageClientId).then (session) =>
      files = _.clone(session.draft().files) ? []
      files.push(file)
      session.changes.add({files})
      session.changes.commit().then ->
        return file

  cancel: ->
    super

    # Note: When you call cancel, we stop the request, which causes
    # NylasAPI.makeRequest to reject with an error.
    return unless @req
    @req.abort()

  # Helper Methods

  _formData: ->
    file: # Must be named `file` as per the Nylas API spec
      value: fs.createReadStream(@filePath)
      options:
        filename: @_uploadData().fileName

  # returns:
  #   messageClientId - The clientId of the message (draft) we're uploading to
  #   filePath - The full absolute local system file path
  #   fileSize - The size in bytes
  #   fileName - The basename of the file
  #   bytesUploaded - Current number of bytes uploaded
  #   state - one of "pending" "started" "progress" "completed" "aborted" "failed"
  _uploadData: (state) ->
    @_memoUploadData ?=
      uploadTaskId: @id
      startDate: @_startDate
      startId: @_startId
      messageClientId: @messageClientId
      filePath: @filePath
      fileSize: @_getFileSize(@filePath)
      fileName: pathUtils.basename(@filePath)
    @_memoUploadData.bytesUploaded = @_getBytesUploaded()
    @_memoUploadData.state = state if state?
    return _.extend({}, @_memoUploadData)

  _getFileSize: (path) ->
    fs.statSync(path)["size"]

  _getBytesUploaded: ->
    # https://github.com/request/request/issues/941
    # http://stackoverflow.com/questions/12098713/upload-progress-request
    @req?.req?.connection?._bytesDispatched ? 0

  _accountId: ->
    AccountStore.current()?.id

module.exports = FileUploadTask
