os = require 'os'
fs = require 'fs'
ipc = require 'ipc'
path = require 'path'
shell = require 'shell'
mkdirp = require 'mkdirp'
Reflux = require 'reflux'
_ = require 'underscore-plus'
Actions = require '../actions'
progress = require 'request-progress'
NamespaceStore = require '../stores/namespace-store'
NylasAPI = require '../nylas-api'

class Download
  constructor: ({@fileId, @targetPath, @progressCallback}) ->
    @percent = 0
    @promise = null
    @

  state: ->
    if not @promise
      'unstarted'
    if @promise.isFulfilled()
      'finished'
    if @promise.isRejected()
      'failed'
    else
      'downloading'

  run: ->
    # If run has already been called, return the existing promise. Never
    # initiate multiple downloads for the same file
    return @promise if @promise

    namespace = NamespaceStore.current()?.id
    @promise = new Promise (resolve, reject) =>
      return reject(new Error("Must pass a fileID to download")) unless @fileId?
      return reject(new Error("Must have a target path to download")) unless @targetPath?

      # Does the file already exist on disk? If so, just resolve immediately.
      fs.exists @targetPath, (exists) =>
        return resolve(@) if exists
        @request = NylasAPI.makeRequest
          path: "/n/#{namespace}/files/#{@fileId}/download"
          success: => resolve(@)
          error: => reject(@)

        progress(@request, {throtte: 250})
        .on("progress", (progress) =>
          @percent = progress.percent
          @progressCallback()
        ).pipe(fs.createWriteStream(@targetPath))

  abort: ->
    @request?.abort()


module.exports =
FileDownloadStore = Reflux.createStore
  init: ->
    @listenTo Actions.fetchFile, @_fetch
    @listenTo Actions.fetchAndOpenFile, @_fetchAndOpen
    @listenTo Actions.fetchAndSaveFile, @_fetchAndSave
    @listenTo Actions.abortDownload, @_cleanupDownload

    @_downloads = []
    @_downloadDirectory = "#{atom.getConfigDirPath()}/downloads"
    mkdirp(@_downloadDirectory)

  ######### PUBLIC #######################################################

  # Returns a hash of download objects keyed by fileId

  pathForFile: (file) ->
    return undefined unless file
    path.join(@_downloadDirectory, "#{file.id}-#{file.filename}")

  downloadForFileId: (fileId) ->
    _.find @_downloads, (d) -> d.fileId is fileId

  downloadsForFileIds: (fileIds=[]) ->
    map = {}
    for fileId in fileIds
      download = @downloadForFileId(fileId)
      map[fileId] = download if download
    map

  ########### PRIVATE ####################################################

  # Returns a promise allowing other actions to be daisy-chained
  # to the end of the download operation
  _startDownload: (file, options = {}) ->
    targetPath = @pathForFile(file)

    # is there an existing download for this file? If so,
    # return that promise so users can chain to the end of it.
    download = _.find @_downloads, (d) -> d.fileId is file.id
    return download.run() if download

    # create a new download for this file and add it to our queue
    download = new Download
      fileId: file.id
      targetPath: targetPath
      progressCallback: => @trigger()

    cleanup = =>
      @_cleanupDownload(download)
      Promise.resolve(download)

    @_downloads.push(download)
    promise = download.run().catch(cleanup).then(cleanup)
    @trigger()
    promise

  _fetch: (file) ->
    @_startDownload(file)

  _fetchAndOpen: (file) ->
    @_startDownload(file).then (download) ->
      shell.openItem(download.targetPath)

  _fetchAndSave: (file) ->
    atom.showSaveDialog @_defaultSavePath(file), (savePath) =>
      return unless savePath
      @_startDownload(file).then (download) ->
        stream = fs.createReadStream(download.targetPath)
        stream.pipe(fs.createWriteStream(savePath))
        stream.on 'end', ->
          shell.showItemInFolder(savePath)

  _cleanupDownload: (download) ->
    download.abort()
    @_downloads = _.without(@_downloads, download)
    @trigger()

  _defaultSavePath: (file) ->
    if process.platform is 'win32'
      home = process.env.USERPROFILE
    else home = process.env.HOME

    downloadDir = path.join(home, 'Downloads')
    if not fs.existsSync(downloadDir)
      downloadDir = os.tmpdir()

    path.join(downloadDir, file.filename)
