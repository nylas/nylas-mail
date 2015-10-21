_ = require 'underscore'
ipc = require 'ipc'
fs = require 'fs'
Reflux = require 'reflux'
Actions = require '../actions'
FileUploadTask = require '../tasks/file-upload-task'

module.exports =
FileUploadStore = Reflux.createStore
  init: ->
    # From Views
    @listenTo Actions.attachFile, @_onAttachFile
    @listenTo Actions.attachFilePath, @_onAttachFilePath
    @listenTo Actions.abortUpload, @_onAbortUpload

    # From Tasks
    @listenTo Actions.uploadStateChanged, @_onUploadStateChanged
    @listenTo Actions.linkFileToUpload, @_onLinkFileToUpload
    @listenTo Actions.fileUploaded, @_onFileUploaded
    @listenTo Actions.fileAborted, @_onFileAborted

    # We don't save uploads to the DB, we keep it in memory in the store.
    # The key is the messageClientId. The value is a hash of paths and
    # corresponding upload data.
    @_fileUploads = {}
    @_linkedFiles = {}


  ######### PUBLIC #######################################################

  uploadsForMessage: (messageClientId) ->
    if not messageClientId? then return []
    _.filter @_fileUploads, (uploadData, uploadKey) ->
      uploadData.messageClientId is messageClientId

  linkedUpload: (file) -> @_linkedFiles[file.id]


  ########### PRIVATE ####################################################

  _onAttachFile: ({messageClientId}) ->
    @_verifyId(messageClientId)

    # When the dialog closes, it triggers `Actions.pathsToOpen`
    atom.showOpenDialog {properties: ['openFile', 'multiSelections']}, (pathsToOpen) ->
      return if not pathsToOpen?
      pathsToOpen = [pathsToOpen] if _.isString(pathsToOpen)

      pathsToOpen.forEach (path) ->
        Actions.attachFilePath({messageClientId, path})

  _onAttachFileError: (message) ->
    remote = require('remote')
    dialog = remote.require('dialog')
    dialog.showMessageBox
      type: 'info',
      buttons: ['OK'],
      message: 'Cannot Attach File',
      detail: message

  _onAttachFilePath: ({messageClientId, path}) ->
    @_verifyId(messageClientId)
    fs.stat path, (err, stats) =>
      filename = require('path').basename(path)
      if err
        @_onAttachFileError("#{filename} could not be found, or has invalid file permissions.")
      else if stats.isDirectory()
        @_onAttachFileError("#{filename} is a directory. Try compressing it and attaching it again.")
      else if stats.size > 25 * 1000000
        @_onAttachFileError("#{filename} cannot be attached because it is larger than 25MB.")
      else
        Actions.queueTask(new FileUploadTask(path, messageClientId))

  # Receives:
  #   uploadData:
  #     uploadTaskId - A unique id
  #     messageClientId - The clientId of the message (draft) we're uploading to
  #     filePath - The full absolute local system file path
  #     fileSize - The size in bytes
  #     fileName - The basename of the file
  #     bytesUploaded - Current number of bytes uploaded
  #     state - one of "pending" "started" "progress" "completed" "aborted" "failed"
  _onUploadStateChanged: (uploadData) ->
    @_fileUploads[uploadData.uploadTaskId] = uploadData
    @_fileUploadTrigger ?= _.throttle =>
      @trigger()
    , 250

    # Note: We throttle file upload updates, because they cause a significant refresh
    # of the composer and when many uploads are running there can be a ton of state
    # changes firing. (To test: drag and drop 20 files onto composer, watch performance.)
    @_fileUploadTrigger()

  _onAbortUpload: (uploadData) ->
    Actions.dequeueMatchingTask
      type: 'FileUploadTask',
      matching:
        id: uploadData.uploadTaskId

  _onLinkFileToUpload: ({file, uploadData}) ->
    @_linkedFiles[file.id] = uploadData
    @trigger()

  _onFileUploaded: ({file, uploadData}) ->
    delete @_fileUploads[uploadData.uploadTaskId]
    @trigger()

  _onFileAborted: (uploadData) ->
    delete @_fileUploads[uploadData.uploadTaskId]
    @trigger()

  _verifyId: (messageClientId) ->
    if messageClientId.blank?
      throw new Error "You need to pass the ID of the message (draft) this Action refers to"
