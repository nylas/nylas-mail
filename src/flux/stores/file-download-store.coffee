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
AccountStore = require '../stores/account-store'
NylasAPI = require '../nylas-api'

Promise.promisifyAll(fs)

mkdirpAsync = (folder) ->
  new Promise (resolve, reject) ->
    mkdirp folder, (err) ->
      if err then reject(err) else resolve(folder)

class Download
  constructor: ({@fileId, @targetPath, @filename, @filesize, @progressCallback}) ->
    if not @filename or @filename.length is 0
      throw new Error("Download.constructor: You must provide a non-empty filename.")
    if not @fileId
      throw new Error("Download.constructor: You must provide a fileID to download.")
    if not @targetPath
      throw new Error("Download.constructor: You must provide a target path to download.")

    @percent = 0
    @promise = null
    @

  state: ->
    if not @promise
      'unstarted'
    else if @promise.isFulfilled()
      'finished'
    else if @promise.isRejected()
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
      accountId = AccountStore.current()?.id
      stream = fs.createWriteStream(@targetPath)
      finished = false
      finishedAction = null

      # We need to watch the request for `success` or `error`, but not fire
      # a callback until the stream has ended. These helper functions ensure
      # that resolve or reject is only fired once regardless of the order
      # these two events (stream end and `success`) happen in.
      streamEnded = =>
        finished = true
        if finishedAction
          finishedAction(@)

      onStreamEnded = (action) =>
        if finished
          action(@)
        else
          finishedAction = action

      NylasAPI.makeRequest
        json: false
        path: "/files/#{@fileId}/download"
        accountId: accountId
        encoding: null # Tell `request` not to parse the response data
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
    @listenTo Actions.abortFetchFile, @_abortFetchFile
    @listenTo Actions.didPassivelyReceiveNewModels, @_newMailReceived

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
    path.join(@_downloadDirectory, file.id, file.displayName())

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

  _newMailReceived: (incoming) =>
    return unless atom.config.get('core.attachments.downloadPolicy') is 'on-receive'
    for message in incoming
      for file in message.files
        @_fetch(file)

  # Returns a promise with a Download object, allowing other actions to be
  # daisy-chained to the end of the download operation.
  _runDownload: (file) ->
    @_prepareFolder(file).then =>
      targetPath = @pathForFile(file)

      # is there an existing download for this file? If so,
      # return that promise so users can chain to the end of it.
      download = @_downloads[file.id]
      return download.run() if download

      # create a new download for this file
      download = new Download
        fileId: file.id
        filesize: file.size
        filename: file.displayName()
        targetPath: targetPath
        progressCallback: => @trigger()

      # Do we actually need to queue and run the download? Queuing a download
      # for an already-downloaded file has side-effects, like making the UI
      # flicker briefly.
      @_checkForDownloadedFile(file).then (alreadyHaveFile) =>
        if alreadyHaveFile
          # If we have the file, just resolve with a resolved download representing the file.
          download.promise = Promise.resolve()
          return Promise.resolve(download)
        else
          @_downloads[file.id] = download
          @trigger()
          return download.run().finally =>
            @_cleanupDownload(download)

  # Returns a promise that resolves with true or false. True if the file has
  # been downloaded, false if it should be downloaded.
  #
  _checkForDownloadedFile: (file) ->
    fs.statAsync(@pathForFile(file)).catch (err) =>
      return Promise.resolve(false)
    .then (stats) =>
      return Promise.resolve(stats.size >= file.size)

  # Checks that the folder for the download is ready. Returns a promise that
  # resolves when the download directory for the file has been created.
  #
  _prepareFolder: (file) ->
    targetFolder = path.join(@_downloadDirectory, file.id)
    fs.statAsync(targetFolder).catch =>
      mkdirpAsync(targetFolder)

  _fetch: (file) ->
    @_runDownload(file).catch ->
      # Passively ignore

  _fetchAndOpen: (file) ->
    @_runDownload(file).then (download) ->
      shell.openItem(download.targetPath)
    .catch =>
      @_presentError(file)

  _fetchAndSave: (file) ->
    atom.showSaveDialog @_defaultSavePath(file), (savePath) =>
      return unless savePath
      @_runDownload(file).then (download) ->
        stream = fs.createReadStream(download.targetPath)
        stream.pipe(fs.createWriteStream(savePath))
        stream.on 'end', ->
          shell.showItemInFolder(savePath)
      .catch =>
        @_presentError(file)

  _abortFetchFile: (file) ->
    download = @_downloads[file.id]
    return unless download
    @_cleanupDownload(download)

    downloadPath = @pathForFile(file)
    fs.exists downloadPath, (exists) ->
      fs.unlink(downloadPath) if exists

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

    path.join(downloadDir, file.displayName())

  _presentError: (file) ->
    dialog = require('remote').require('dialog')
    dialog.showMessageBox
      type: 'warning'
      message: "Download Failed"
      detail: "Unable to download #{file.displayName()}.
               Check your network connection and try again."
      buttons: ["OK"]

# Expose the Download class for our tests, and possibly for other things someday
FileDownloadStore.Download = Download
