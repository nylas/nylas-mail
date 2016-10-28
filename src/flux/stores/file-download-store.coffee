os = require 'os'
fs = require 'fs'
path = require 'path'
{remote, shell} = require 'electron'
mkdirp = require 'mkdirp'
Utils = require '../models/utils'
Reflux = require 'reflux'
_ = require 'underscore'
Actions = require('../actions').default
progress = require 'request-progress'
NylasAPI = require '../nylas-api'
RegExpUtils = require '../../regexp-utils'

Promise.promisifyAll(fs)
mkdirpAsync = Promise.promisify(mkdirp)

State =
  Unstarted: 'unstarted'
  Downloading: 'downloading'
  Finished: 'finished'
  Failed: 'failed'

class Download
  @State: State

  constructor: ({@accountId, @fileId, @targetPath, @filename, @filesize, @progressCallback}) ->
    if not @accountId
      throw new Error("Download.constructor: You must provide a non-empty accountId.")
    if not @filename or @filename.length is 0
      throw new Error("Download.constructor: You must provide a non-empty filename.")
    if not @fileId
      throw new Error("Download.constructor: You must provide a fileID to download.")
    if not @targetPath
      throw new Error("Download.constructor: You must provide a target path to download.")

    @percent = 0
    @promise = null
    @state = State.Unstarted
    @

  # We need to pass a plain object so we can have fresh references for the
  # React views while maintaining the single object with the running
  # request.
  data: -> Object.freeze _.clone
    state: @state
    fileId: @fileId
    percent: @percent
    filename: @filename
    filesize: @filesize
    targetPath: @targetPath

  run: ->
    # If run has already been called, return the existing promise. Never
    # initiate multiple downloads for the same file
    return @promise if @promise

    # Note: we must resolve or reject with `this`
    @promise = new Promise (resolve, reject) =>
      stream = fs.createWriteStream(@targetPath)
      @state = State.Downloading

      onFailed = (err) =>
        @request = null
        stream.end()
        @state = State.Failed
        if fs.existsSync(@targetPath)
          fs.unlinkSync(@targetPath)
        reject(err)

      onSuccess = =>
        @request = null
        stream.end()
        @state = State.Finished
        @percent = 100
        resolve(@)

      NylasAPI.makeRequest
        json: false
        path: "/files/#{@fileId}/download"
        accountId: @accountId
        encoding: null # Tell `request` not to parse the response data
        started: (req) =>
          @request = req
          progress(@request, {throtte: 250})
          .on "progress", (progress) =>
            @percent = progress.percent
            @progressCallback()

          # This is a /socket/ error event, not an HTTP error event. It fires
          # when the conn is dropped, user if offline, but not on HTTP status codes.
          # It is sometimes called in place of "end", not before or after.
          .on("error", onFailed)

          .on "end", =>
            return if @state is State.Failed

            statusCode = @request.response?.statusCode
            if [200, 202, 204].includes(statusCode)
              onSuccess()
            else
              onFailed(new Error("Server returned a #{statusCode}"))

          .pipe(stream)

  ensureClosed: ->
    @request?.abort()


module.exports =
FileDownloadStore = Reflux.createStore
  init: ->
    @listenTo Actions.fetchFile, @_fetch
    @listenTo Actions.fetchAndOpenFile, @_fetchAndOpen
    @listenTo Actions.fetchAndSaveFile, @_fetchAndSave
    @listenTo Actions.fetchAndSaveAllFiles, @_fetchAndSaveAll
    @listenTo Actions.abortFetchFile, @_abortFetchFile
    @listenTo Actions.didPassivelyReceiveNewModels, @_newMailReceived

    @_downloads = {}
    @_downloadDirectory = path.join(NylasEnv.getConfigDirPath(), 'downloads')
    mkdirp(@_downloadDirectory)

  ######### PUBLIC #######################################################

  # Returns a path on disk for saving the file. Note that we must account
  # for files that don't have a name and avoid returning <downloads/dir/"">
  # which causes operations to happen on the directory (badness!)
  #
  pathForFile: (file) ->
    return undefined unless file
    path.join(@_downloadDirectory, file.id, file.safeDisplayName())

  downloadDataForFile: (fileId) ->
    @_downloads[fileId]?.data()

  # Returns a hash of download objects keyed by fileId
  #
  downloadDataForFiles: (fileIds=[]) ->
    downloadData = {}
    fileIds.forEach (fileId) =>
      downloadData[fileId] = @downloadDataForFile(fileId)
    return downloadData

  ########### PRIVATE ####################################################

  _newMailReceived: (incoming) ->
    if NylasEnv.config.get('core.attachments.downloadPolicy') is 'on-receive'
      return unless incoming['message']
      for message in incoming['message']
        for file in message.files
          @_fetch(file)

  # Returns a promise with a Download object, allowing other actions to be
  # daisy-chained to the end of the download operation.
  _runDownload: (file) ->
    targetPath = @pathForFile(file)

    # is there an existing download for this file? If so,
    # return that promise so users can chain to the end of it.
    download = @_downloads[file.id]
    return download.run() if download

    # create a new download for this file
    download = new Download
      accountId: file.accountId
      fileId: file.id
      filesize: file.size
      filename: file.displayName()
      targetPath: targetPath
      progressCallback: => @trigger()

    # Do we actually need to queue and run the download? Queuing a download
    # for an already-downloaded file has side-effects, like making the UI
    # flicker briefly.
    @_prepareFolder(file).then =>
      @_checkForDownloadedFile(file).then (alreadyHaveFile) =>
        if alreadyHaveFile
          # If we have the file, just resolve with a resolved download representing the file.
          download.promise = Promise.resolve()
          download.state = State.Finished
          return Promise.resolve(download)
        else
          @_downloads[file.id] = download
          @trigger()
          return download.run().finally =>
            download.ensureClosed()
            if download.state is State.Failed
              delete @_downloads[file.id]
            @trigger()

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
    @_runDownload(file)
    .catch(@_catchFSErrors)
    .catch (error) ->
      # Passively ignore

  _fetchAndOpen: (file) ->
    @_runDownload(file).then (download) ->
      shell.openItem(download.targetPath)
    .catch(@_catchFSErrors)
    .catch (error) =>
      @_presentError({file, error})

  _saveDownload: (download, savePath) =>
    return new Promise (resolve, reject) =>
      stream = fs.createReadStream(download.targetPath)
      stream.pipe(fs.createWriteStream(savePath))
      stream.on 'error', (err) -> reject(err)
      stream.on 'end', -> resolve()

  _fetchAndSave: (file) ->
    defaultPath = @_defaultSavePath(file)
    defaultExtension = path.extname(defaultPath)

    NylasEnv.showSaveDialog {defaultPath}, (savePath) =>
      return unless savePath

      newDownloadDirectory = path.dirname(savePath)
      saveExtension = path.extname(savePath)
      didLoseExtension = defaultExtension isnt '' and saveExtension is ''
      if didLoseExtension
        savePath = savePath + defaultExtension

      @_runDownload(file)
      .then (download) => @_saveDownload(download, savePath)
      .then =>
        if NylasEnv.savedState.lastDownloadDirectory isnt newDownloadDirectory
          shell.showItemInFolder(savePath)
          NylasEnv.savedState.lastDownloadDirectory = newDownloadDirectory
      .catch(@_catchFSErrors)
      .catch (error) =>
        @_presentError({file, error})

  _fetchAndSaveAll: (files) ->
    defaultPath = @_defaultSaveDir()
    options = {
      defaultPath,
      title: 'Save Into...',
      buttonLabel: 'Download All',
      properties: ['openDirectory', 'createDirectory'],
    }

    return new Promise (resolve, reject) =>
      NylasEnv.showOpenDialog options, (selected) =>
        return unless selected
        dirPath = selected[0]
        return unless dirPath
        NylasEnv.savedState.lastDownloadDirectory = dirPath

        lastSavePaths = []
        savePromises = files.map (file) =>
          savePath = path.join(dirPath, file.safeDisplayName())
          @_runDownload(file)
          .then (download) => @_saveDownload(download, savePath)
          .then ->
            lastSavePaths.push(savePath)

        Promise.all(savePromises)
        .then =>
          shell.showItemInFolder(lastSavePaths[0]) if lastSavePaths.length > 0
          resolve(lastSavePaths)
        .catch(@_catchFSErrors)
        .catch =>
          @_presentError(file)

  _abortFetchFile: (file) ->
    download = @_downloads[file.id]
    return unless download
    download.ensureClosed()
    @trigger()

    downloadPath = @pathForFile(file)
    fs.exists downloadPath, (exists) ->
      fs.unlink(downloadPath) if exists

  _defaultSaveDir: ->
    if process.platform is 'win32'
      home = process.env.USERPROFILE
    else
      home = process.env.HOME

    downloadDir = path.join(home, 'Downloads')
    if not fs.existsSync(downloadDir)
      downloadDir = os.tmpdir()

    if NylasEnv.savedState.lastDownloadDirectory
      if fs.existsSync(NylasEnv.savedState.lastDownloadDirectory)
        downloadDir = NylasEnv.savedState.lastDownloadDirectory

    return downloadDir

  _defaultSavePath: (file) ->
    downloadDir = @_defaultSaveDir()
    path.join(downloadDir, file.safeDisplayName())

  _presentError: ({file, error} = {}) ->
    name = if file then file.displayName() else "one or more files"
    errorString = if error then error.toString() else ""

    remote.dialog.showMessageBox
      type: 'warning'
      message: "Download Failed"
      detail: "Unable to download #{name}. Check your network connection and try again. #{errorString}"
      buttons: ["OK"]

  _catchFSErrors: (error) ->
    message = null
    if error.code in ['EPERM', 'EMFILE', 'EACCES']
      message = "N1 could not save an attachment. Check that permissions are set correctly and try restarting N1 if the issue persists."
    if error.code in ['ENOSPC']
      message = "N1 could not save an attachment because you have run out of disk space."

    if message
      remote.dialog.showMessageBox
        type: 'warning'
        message: "Download Failed"
        detail: "#{message}\n\n#{error.message}"
        buttons: ["OK"]
      return Promise.resolve()
    else
      return Promise.reject(error)

# Expose the Download class for our tests, and possibly for other things someday
FileDownloadStore.Download = Download
