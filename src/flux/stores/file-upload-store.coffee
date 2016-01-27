_ = require 'underscore'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
NylasStore = require 'nylas-store'
Actions = require '../actions'
Utils = require '../models/utils'
Message = require '../models/message'
DatabaseStore = require './database-store'


UPLOAD_DIR = path.join(NylasEnv.getConfigDirPath(), 'uploads')

class Upload

  constructor: (@messageClientId, @originPath, @stats, @id, @uploadDir = UPLOAD_DIR) ->
    @id ?= Utils.generateTempId()
    @filename = path.basename(@originPath)
    @draftUploadDir = path.join(@uploadDir, @messageClientId)
    @targetDir = path.join(@draftUploadDir, @id)
    @targetPath = path.join(@targetDir, @filename)
    @size = @stats.size


class FileUploadStore extends NylasStore

  Upload: Upload

  constructor: ->
    @listenTo Actions.selectAttachment, @_onSelectAttachment
    @listenTo Actions.addAttachment, @_onAddAttachment
    @listenTo Actions.removeAttachment, @_onRemoveAttachment
    @listenTo DatabaseStore, @_onDataChanged

    mkdirp.sync(UPLOAD_DIR)
    @_fileUploads = @_getFileUploadsFromFs()

  uploadsForMessage: (messageClientId) ->
    [].concat(@_fileUploads[messageClientId] ? [])


  # Handlers

  _onDataChanged: (change) =>
    return unless NylasEnv.isMainWindow()
    return unless change.objectClass is Message.name and change.type is 'unpersist'
    change.objects.forEach (message) =>
      uploads = @_fileUploads[message.clientId]
      if uploads?
        uploads.forEach (upload) => @_onRemoveAttachment(upload)

  _onSelectAttachment: ({messageClientId}) ->
    @_verifyId(messageClientId)
    # When the dialog closes, it triggers `Actions.addAttachment`
    NylasEnv.showOpenDialog {properties: ['openFile', 'multiSelections']}, (pathsToOpen) ->
      return if not pathsToOpen?
      pathsToOpen = [pathsToOpen] if _.isString(pathsToOpen)

      pathsToOpen.forEach (filePath) ->
        Actions.addAttachment({messageClientId, filePath})

  _onAddAttachment: ({messageClientId, filePath}) ->
    @_verifyId(messageClientId)
    @_getFileStats({messageClientId, filePath})
    .then(@_makeUpload)
    .then(@_verifyUpload)
    .then(@_prepareTargetDir)
    .then(@_copyUpload)
    .then(@_saveUpload)
    .catch(@_onAttachFileError)

  _onRemoveAttachment: (upload) ->
    return Promise.resolve() unless (@_fileUploads[upload.messageClientId] ? []).length > 0
    @_deleteUpload(upload)
    .then (upload) =>
      {messageClientId} = upload
      uploads = @_fileUploads[messageClientId]
      uploads = _.reject(uploads, ({id}) -> id is upload.id)
      @_fileUploads[messageClientId] = uploads
      fs.rmdir(upload.draftUploadDir) if uploads.length is 0
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


  # Helpers

  _getTempIdDirsFor: (path) ->
    fs.readdirSync(path).filter((dir) -> Utils.isTempId(dir))

  _getFileUploadsFromFs: (rootDir = UPLOAD_DIR)->
    # TODO This function makes my eyes hurt. Refactor
    uploads = {}
    dirs = @_getTempIdDirsFor(rootDir)
    for messageClientId in dirs
      uploads[messageClientId] = []
      messageDir = path.join(rootDir, messageClientId)
      uploadIds = @_getTempIdDirsFor(messageDir)
      for uploadId in uploadIds
        uploadDir = path.join(messageDir, uploadId)
        for filename in fs.readdirSync(uploadDir)
          uploadPath = path.join(uploadDir, filename)
          stats = fs.statSync(uploadPath)
          uploads[messageClientId].push(
            new Upload(messageClientId, uploadPath, stats, uploadId)
          )
    return uploads

  _verifyId: (messageClientId) ->
    unless messageClientId
      throw new Error "You need to pass the ID of the message (draft) this Action refers to"

  _getFileStats: ({messageClientId, filePath}) ->
    return new Promise (resolve, reject) ->
      fs.stat filePath, (err, stats) =>
        if err
          reject("#{filePath} could not be found, or has invalid file permissions.")
        else
          resolve({messageClientId, filePath, stats})

  _makeUpload: ({messageClientId, filePath, stats}) ->
    Promise.resolve(new Upload(messageClientId, filePath, stats))

  _verifyUpload: (upload) ->
    {filename, stats} = upload
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
          reject("Error removing directory for file #{upload.filename}") if err
          resolve(upload)

  _saveUpload: (upload) =>
    @_fileUploads[upload.messageClientId] ?= []
    @_fileUploads[upload.messageClientId].push(upload)
    @trigger()
    Promise.resolve()


module.exports = new FileUploadStore()
