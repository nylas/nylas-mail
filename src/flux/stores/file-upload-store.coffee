_ = require 'underscore'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
NylasStore = require 'nylas-store'
Actions = require '../actions'

UPLOAD_DIR = path.join(NylasEnv.getConfigDirPath(), 'uploads')

class Upload

  constructor: (@messageClientId, @originPath, @stats, @uploadDir = UPLOAD_DIR) ->
    @id = Utils.generateTempId()
    @filename = path.basename(@originPath)
    @targetDir = path.join(@uploadDir, @messageClientId, @id)
    @targetPath = path.join(@targetDir, @filename)
    @size = @stats.size


class FileUploadStore extends NylasStore

  constructor: ->
    @listenTo Actions.selectFileForUpload, @_onSelectFileForUpload
    @listenTo Actions.attachFile, @_onAttachFile
    @listenTo Actions.removeFileFromUpload, @_onRemoveUpload

    # We don't save uploads to the DB, we keep it in memory in the store.
    # The key is the messageClientId. The value is a hash of paths and
    # corresponding upload data.
    @_fileUploads = {}
    mkdirp(UPLOAD_DIR)

  uploadsForMessage: (messageClientId) ->
    @_fileUploads[messageClientId] ? []

  _onSelectFileForUpload: ({messageClientId}) ->
    @_verifyId(messageClientId)
    # When the dialog closes, it triggers `Actions.attachFile`
    NylasEnv.showOpenDialog {properties: ['openFile', 'multiSelections']}, (pathsToOpen) ->
      return if not pathsToOpen?
      pathsToOpen = [pathsToOpen] if _.isString(pathsToOpen)

      pathsToOpen.forEach (filePath) ->
        Actions.attachFile({messageClientId, filePath})

  _onAttachFile: ({messageClientId, filePath}) ->
    @_verifyId(messageClientId)
    @_getFileStats({messageClientId, filePath})
    .then(@_makeUpload)
    .then(@_verifyUpload)
    .then(@_prepareTargetDir)
    .then(@_copyUpload)
    .then(@_saveUpload)
    .catch(@_onAttachFileError)

  _onRemoveUpload: (upload) ->
    return unless (@_fileUploads[upload.messageClientId] ? []).length > 0
    @_deleteUpload(upload)
    .then (upload) =>
      uploads = @_fileUploads[upload.messageClientId]
      uploads = _.reject(uploads, ({id}) -> id is upload.id)
      @trigger()
    .catch(@_onAttachFileError)

  _onAttachFileError: (message) ->
    remote = require('remote')
    dialog = remote.require('dialog')
    dialog.showMessageBox
      type: 'info',
      buttons: ['OK'],
      message: 'Cannot Attach File',
      detail: message

  _verifyId: (messageClientId) ->
    if messageClientId.blank?
      throw new Error "You need to pass the ID of the message (draft) this Action refers to"

  _getFileStats: ({messageClientId, filePath}) ->
    fs.stat filePath, (err, stats) =>
      if err
        Promise.reject("#{filePath} could not be found, or has invalid file permissions.")
      else
        Promise.resolve({messageClientId, filePath, stats})

  _makeUpload: ({messageClientId, filePath, stats}) ->
    Promise.resolve(new Upload(messageClientId, filePath, stats))

  _verifyUpload: (upload) ->
    {stats} = upload
    if stats.isDirectory()
      Promise.reject("#{filename} is a directory. Try compressing it and attaching it again.")
    else if stats.size > 25 * 1000000
      Promise.reject("#{filename} cannot be attached because it is larger than 25MB.")
    else
      Promise.resolve(upload)

  _prepareTargetDir: (upload) =>
    return new Promise (resolve, reject) ->
      mkdirp upload.targetDir, (err) ->
        if err
          reject("Error creating folder for upload: `#{upload.filename}`")
        else
          resolve(upload)

  _copyUpload: (upload) ->
    return new Promise (resolve, reject) =>
      {originPath, targetPath} = upload
      readStream = fs.createReadStream(originPath)
      writeStream = fs.createWriteStream(targetPath)

      readStream.on 'error', ->
        reject("Error while reading file from #{originPath}")
      writeStream.on 'error', ->
        reject("Error while writing file #{upload.filename}")
      readStream.on 'end', ->
        resolve(upload)
      readStream.pipe(writeStream)

  _deleteUpload: (upload) ->
    return new Promise (resolve, reject) ->
      fs.unlink upload.targetPath, (err) ->
        reject("Error removing file #{upload.filename}") if err
        fs.rmdir upload.targetDir, (err) ->
          reject("Error removing file #{upload.filename}") if err
          resolve(upload)

  _saveUpload: (upload) =>
    @_fileUploads[upload.messageClientId] ?= []
    @_fileUploads[upload.messageClientId].push(upload)
    @trigger()


module.exports = new FileUploadStore()
