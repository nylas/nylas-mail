os = require 'os'
fs = require 'fs'
ipc = require 'ipc'
path = require 'path'
shell = require 'shell'
mkdirp = require 'mkdirp'
Utils = require '../models/utils'
Reflux = require 'reflux'
_ = require 'underscore'
Actions = require '../actions'
progress = require 'request-progress'
NamespaceStore = require '../stores/namespace-store'
NylasAPI = require '../nylas-api'

class Download
  constructor: ({@fileId, @targetPath, @filename, @filesize, @progressCallback}) ->
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

  # We need to pass a plain object so we can have fresh references for the
  # React views while maintaining the single object with the running
  # request.
  data: -> Object.freeze _.clone
    state: @state()
    fileId: @fileId
    percent: @percent
    filename: @filename
    filesize: @filesize
    targetPath: @targetPath

  run: ->
    # If run has already been called, return the existing promise. Never
    # initiate multiple downloads for the same file
    return @promise if @promise

    @promise = new Promise (resolve, reject) =>
      return reject(new Error("Must pass a fileID to download")) unless @fileId?
      return reject(new Error("Must have a target path to download")) unless @targetPath?

      fs.exists @targetPath, (exists) =>
        # Does the file already exist on disk? If so, just resolve immediately.
        if exists
          fs.stat @targetPath, (err, stats) =>
            if not err and stats.size >= @filesize
              return resolve(@)
            else
              @_doDownload(resolve, reject)
        else
          @_doDownload(resolve, reject)

  _doDownload: (resolve, reject) =>
    namespace = NamespaceStore.current()?.id
    stream = fs.createWriteStream(@targetPath)
    finished = false
    finishedAction = null

    # We need to watch the request for `success` or `error`, but not fire
    # a callback until the stream has ended. These helper functions ensure
    # that resolve or reject is only fired once regardless of the order
    # these two events (stream end and `success`) happen in.
    streamEnded = ->
      finished = true
      if finishedAction
        finishedAction(@)

    onStreamEnded = (action) ->
      if finished
        action(@)
      else
        finishedAction = action

    NylasAPI.makeRequest
      json: false
      path: "/n/#{namespace}/files/#{@fileId}/download"
      started: (req) =>
        @request = req
        progress(@request, {throtte: 250})
        .on "progress", (progress) =>
          @percent = progress.percent
          @progressCallback()
        .on "end", =>
          # Wait for the file stream to finish writing before we resolve or reject
          stream.end(streamEnded)
        .pipe(stream)

      success: =>
        # At this point, the file stream has not finished writing to disk.
        # Don't resolve yet, or the browser will load only part of the image.
        onStreamEnded(resolve)

      error: =>
        onStreamEnded(reject)

  abort: ->
    @request?.abort()


module.exports =
FileDownloadStore = Reflux.createStore
  init: ->
    @listenTo Actions.fetchFile, @_fetch
    @listenTo Actions.fetchAndOpenFile, @_fetchAndOpen
    @listenTo Actions.fetchAndSaveFile, @_fetchAndSave
    @listenTo Actions.abortDownload, @_abortDownload

    @_downloads = {}
    @_downloadDirectory = "#{atom.getConfigDirPath()}/downloads"
    mkdirp(@_downloadDirectory)

  ######### PUBLIC #######################################################

  # Returns a path on disk for saving the file. Note that we must account
  # for files that don't have a name and avoid returning <downloads/dir/"">
  # which causes operations to happen on the directory (badness!)
  #
  pathForFile: (file) ->
    return undefined unless file
    if file.filename and file.filename.length > 0
      downloadFilename = file.filename
    else
      downloadFilename = file.id
    path.join(@_downloadDirectory, file.id, downloadFilename)

  downloadDataForFile: (fileId) -> @_downloads[fileId]?.data()

  # Returns a hash of download objects keyed by fileId
  #
  downloadDataForFiles: (fileIds=[]) ->
    downloadData = {}
    fileIds.forEach (fileId) =>
      data = @downloadDataForFile(fileId)
      return unless data
      downloadData[fileId] = data
    return downloadData

  ########### PRIVATE ####################################################

  # Returns a promise allowing other actions to be daisy-chained
  # to the end of the download operation
  _startDownload: (file, options = {}) ->
    @_prepareFolder(file).then =>
      targetPath = @pathForFile(file)

      # is there an existing download for this file? If so,
      # return that promise so users can chain to the end of it.
      download = @_downloads[file.id]
      return download.run() if download

      # create a new download for this file and add it to our queue
      download = new Download
        fileId: file.id
        filesize: file.size
        filename: file.filename
        targetPath: targetPath
        progressCallback: => @trigger()

      cleanup = =>
        @_cleanupDownload(download)
        Promise.resolve(download)

      @_downloads[file.id] = download
      promise = download.run().catch(cleanup).then(cleanup)
      @trigger()
      return promise

  _prepareFolder: (file) ->
    new Promise (resolve, reject) =>
      folder = path.join(@_downloadDirectory, file.id)
      fs.exists folder, (exists) =>
        if exists then resolve(folder)
        else
          mkdirp folder, (err) =>
            if err then reject(err) else resolve(folder)

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

  _abortDownload: (downloadData) ->
    download = @_downloads[downloadData.fileId]
    return unless download
    @_cleanupDownload(download)
    p = @pathForFile
      id: downloadData.fileId
      filename: downloadData.filename
    fs.unlinkSync(p)

  _cleanupDownload: (download) ->
    download.abort()
    delete @_downloads[download.fileId]
    @trigger()

  _defaultSavePath: (file) ->
    if process.platform is 'win32'
      home = process.env.USERPROFILE
    else home = process.env.HOME

    downloadDir = path.join(home, 'Downloads')
    if not fs.existsSync(downloadDir)
      downloadDir = os.tmpdir()

    path.join(downloadDir, file.filename)
