_ = require 'underscore-plus'
ipc = require 'ipc'
Reflux = require 'reflux'
Actions = require '../actions'
FileUploadTask = require '../tasks/file-upload-task'

module.exports =
FileUploadStore = Reflux.createStore
  init: ->
    # From Views
    @listenTo Actions.attachFile, @_onAttachFile
    @listenTo Actions.abortUpload, @_onAbortUpload

    # From Tasks
    @listenTo Actions.uploadStateChanged, @_onUploadStateChanged
    @listenTo Actions.fileUploaded, @_onFileUploaded
    @listenTo Actions.fileAborted, @_onFileAborted

    # We don't save uploads to the DB, we keep it in memory in the store.
    # The key is the messageLocalId. The value is a hash of paths and
    # corresponding upload data.
    @_fileUploads = {}


  ######### PUBLIC #######################################################

  uploadsForMessage: (messageLocalId) ->
    if not messageLocalId? then return {}
    _.filter @_fileUploads, (uploadData, uploadKey) ->
      uploadData.messageLocalId is messageLocalId


  ########### PRIVATE ####################################################

  _onAttachFile: ({messageLocalId}) ->
    @_verifyId(messageLocalId)

    unlistenOpen = Actions.openPathsSelected.listen (pathsToOpen=[]) ->
      unlistenOpen?()
      pathsToOpen = [pathsToOpen] if _.isString(pathsToOpen)
      for path in pathsToOpen
        # When this task runs, we expect to hear `uploadStateChanged`
        # Actions.
        Actions.queueTask(new FileUploadTask(path, messageLocalId))

    # When the dialog closes, it triggers `Actions.pathsToOpen`
    ipc.send('command', 'application:open-file-to-window')

  # Receives:
  #   uploadData:
  #     messageLocalId - The localId of the message (draft) we're uploading to
  #     filePath - The full absolute local system file path
  #     fileSize - The size in bytes
  #     fileName - The basename of the file
  #     bytesUploaded - Current number of bytes uploaded
  #     state - one of "pending" "started" "progress" "completed" "aborted" "failed"
  _onUploadStateChanged: (uploadData) ->
    @_fileUploads[@_uploadId(uploadData)] = uploadData
    @trigger()

  _onAbortUpload: (uploadData) ->
    Actions.abortTask({
      object: 'FileUploadTask',
      filePath: uploadData.filePath,
      messageLocalId: uploadData.messageLocalId
    })

  # Note that the MessageStore also receives the `fileUploaded` action.
  # It will trigger the change in message object.
  _onFileUploaded: ({file, uploadData}) ->
    delete @_fileUploads[@_uploadId(uploadData)]
    @trigger()

  _onFileAborted: (uploadData) ->
    delete @_fileUploads[@_uploadId(uploadData)]
    @trigger()

  _uploadId: (uploadData) ->
    "#{uploadData.messageLocalId} #{uploadData.filePath}"

  _verifyId: (messageLocalId) ->
    if messageLocalId.blank?
      throw new Error "You need to pass the ID of the message (draft) this Action refers to"
