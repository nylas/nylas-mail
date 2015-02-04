os = require 'os'
fs = require 'fs'
ipc = require 'ipc'
path = require 'path'
shell = require 'shell'
Reflux = require 'reflux'
Actions = require '../actions'
DownloadFileTask = require '../tasks/download-file'

module.exports =
FileDownloadStore = Reflux.createStore
  init: ->
    # From Views
    @listenTo Actions.viewFile, @_onViewFile
    @listenTo Actions.saveFile, @_onSaveFile
    @listenTo Actions.abortDownload, @_onAbortDownload

    # From Tasks
    @listenTo Actions.downloadStateChanged, @_onDownloadStateChanged
    @listenTo Actions.fileDownloaded, @_onFileDownloaded

    # Keyed by fileId
    @_fileDownloads = {}


  ######### PUBLIC #######################################################

  # Returns a hash of fileDownloads keyed by fileId
  downloadsForFiles: (fileIds=[]) ->
    downloads = {}
    for fileId in fileIds
      downloads[fileId] = @_fileDownloads[fileId] if @_fileDownloads[fileId]?
    return downloads

  ########### PRIVATE ####################################################

  _onViewFile: (file) ->
    Actions.queueTask new DownloadFileTask
      fileId: file.id
      shellAction: "openItem" # Safe to serialize
      downloadPath: path.join(os.tmpDir(), file.filename)

  _onSaveFile: (file) ->
    # We setup the listener here because we don't want to catch someone
    # else's open dialog
    unlistenSave = Actions.savePathSelected.listen (pathToSave) =>
      unlistenSave?()
      if pathToSave?
        @_actionAfterDownload = "showItemInFolder"
        Actions.queueTask new DownloadFileTask
          fileId: file.id
          shellAction: "showItemInFolder"
          downloadPath: pathToSave

    # When the dialog closes, it triggers `Actions.pathToSave`
    ipc.send('save-file', @_defaultSavePath(file))

  _onAbortDownload: (file) ->
    Actions.abortTask({object: 'DownloadFileTask', fileId: file.id})

  # Generated in tasks/download-file.coffee
  # downloadData:
  #   state - One of "pending "started" "progress" "completed" "aborted" "failed"
  #   fileId - The id of the file
  #   shellAction - Action used to open the file after downloading
  #   downloadPath - The full path of the download location
  #   total - From request-progress: total number of bytes
  #   percent - From request-progress
  #   received - From request-progress: currently received bytes
  _onDownloadStateChanged: (downloadData={}) ->
    @_fileDownloads[downloadData.fileId] = downloadData
    @trigger()

  _onFileDownloaded: ({fileId, shellAction, downloadPath}) ->
    delete @_fileDownloads[fileId]
    @trigger()
    shell[shellAction](downloadPath)

  _defaultSavePath: (file) ->
    if process.platform is 'win32'
      home = process.env.USERPROFILE
    else home = process.env.HOME

    downloadDir = path.join(home, 'Downloads')
    if not fs.existsSync(downloadDir)
      downloadDir = os.tmpdir()
    else

    path.join(downloadDir, file.filename)
