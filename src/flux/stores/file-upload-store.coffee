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
    # The key is the messageLocalId. The value is a hash of paths and
    # corresponding upload data.
    @_fileUploads = {}
    @_linkedFiles = {}


  ######### PUBLIC #######################################################

  uploadsForMessage: (messageLocalId) ->
    if not messageLocalId? then return []
    _.filter @_fileUploads, (uploadData, uploadKey) ->
      uploadData.messageLocalId is messageLocalId

  linkedUpload: (file) -> @_linkedFiles[file.id]


  ########### PRIVATE ####################################################

  _onAttachFile: ({messageLocalId}) ->
    @_verifyId(messageLocalId)

    # When the dialog closes, it triggers `Actions.pathsToOpen`
    atom.showOpenDialog {properties: ['openFile', 'multiSelections']}, (pathsToOpen) ->
      return if not pathsToOpen?
      pathsToOpen = [pathsToOpen] if _.isString(pathsToOpen)

      pathsToOpen.forEach (path) ->
        Actions.attachFilePath({messageLocalId, path})

  _onAttachFileError: (message) ->
    remote = require('remote')
    dialog = remote.require('dialog')
    dialog.showMessageBox
      type: 'info',
      buttons: ['OK'],
      message: 'Cannot Attach File',
      detail: message

  _onAttachFilePath: ({messageLocalId, path}) ->
    @_verifyId(messageLocalId)
    fs.stat path, (err, stats) =>
      return if err
      if stats.isDirectory()
        filename = require('path').basename(path)
        @_onAttachFileError("#{filename} is a directory. Try compressing it and attaching it again.")
      else
        Actions.queueTask(new FileUploadTask(path, messageLocalId))

  # Receives:
  #   uploadData:
  #     uploadTaskId - A unique id
  #     messageLocalId - The localId of the message (draft) we're uploading to
  #     filePath - The full absolute local system file path
  #     fileSize - The size in bytes
  #     fileName - The basename of the file
  #     bytesUploaded - Current number of bytes uploaded
  #     state - one of "pending" "started" "progress" "completed" "aborted" "failed"
  _onUploadStateChanged: (uploadData) ->
    @_fileUploads[uploadData.uploadTaskId] = uploadData
    @trigger()

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

  _verifyId: (messageLocalId) ->
    if messageLocalId.blank?
      throw new Error "You need to pass the ID of the message (draft) this Action refers to"
