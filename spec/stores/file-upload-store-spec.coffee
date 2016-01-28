fs = require 'fs'
{Message,
 Actions,
 FileUploadStore,
 DraftStore} = require 'nylas-exports'
{Upload} = FileUploadStore

msgId = "local-123"
fpath = "/foo/bar/test123.jpg"
fDir = "/foo/bar"
uploadDir = "/uploads"
filename = "test123.jpg"
argsObj = {messageClientId: msgId, filePath: fpath}

describe 'FileUploadStore', ->

  beforeEach ->
    @draft = new Message()
    @session =
      changes:
        add: jasmine.createSpy('session.changes.add')
      draft: => @draft
    spyOn(NylasEnv, "isMainWindow").andReturn true
    spyOn(FileUploadStore, "_onAttachFileError").andCallFake (msg) ->
      throw new Error(msg)
    spyOn(NylasEnv, "showOpenDialog").andCallFake (props, callback) ->
      callback(fpath)
    spyOn(DraftStore, "sessionForClientId").andCallFake => Promise.resolve @session

  describe 'selectAttachment', ->
    it "throws if no messageClientId is provided", ->
      expect( -> Actions.selectAttachment()).toThrow()

    it "throws if messageClientId is blank", ->
      expect( -> Actions.selectAttachment("")).toThrow()

    it "dispatches action to attach file", ->
      spyOn(Actions, "addAttachment")

      Actions.selectAttachment(messageClientId: msgId)
      expect(NylasEnv.showOpenDialog).toHaveBeenCalled()
      expect(Actions.addAttachment).toHaveBeenCalled()
      args = Actions.addAttachment.calls[0].args[0]
      expect(args.messageClientId).toBe msgId
      expect(args.filePath).toBe fpath


  describe 'addAttachment', ->
    beforeEach ->
      @upload = new Upload(msgId, fpath, {size: 1234, isDirectory: -> false}, 'u1', uploadDir)
      spyOn(FileUploadStore, '_getFileStats').andCallFake -> Promise.resolve()
      spyOn(FileUploadStore, '_makeUpload').andCallFake -> Promise.resolve()
      spyOn(FileUploadStore, '_verifyUpload').andCallFake -> Promise.resolve()
      spyOn(FileUploadStore, '_prepareTargetDir').andCallFake -> Promise.resolve()
      spyOn(FileUploadStore, '_copyUpload').andCallFake => Promise.resolve(@upload)
      spyOn(FileUploadStore, '_saveUpload').andCallThrough()

    it "throws if no messageClientId or path is provided", ->
      expect(-> Actions.addAttachment()).toThrow()

    it "executes the required steps and triggers", ->
      waitsForPromise ->
        FileUploadStore._onAddAttachment(argsObj)

      runs =>
        expect(FileUploadStore._getFileStats).toHaveBeenCalled()
        expect(FileUploadStore._makeUpload).toHaveBeenCalled()
        expect(FileUploadStore._verifyUpload).toHaveBeenCalled()
        expect(FileUploadStore._prepareTargetDir).toHaveBeenCalled()
        expect(FileUploadStore._copyUpload).toHaveBeenCalled()
        expect(FileUploadStore._saveUpload).toHaveBeenCalled()
        expect(@session.changes.add).toHaveBeenCalledWith({uploads: [@upload]})


  describe 'removeAttachment', ->
    beforeEach ->
      @upload = new Upload(msgId, fpath, {size: 1234, isDirectory: -> false}, 'u1', uploadDir)
      spyOn(FileUploadStore, '_deleteUpload').andCallFake => Promise.resolve(@upload)
      spyOn(fs, 'rmdir')

    it 'removes upload correctly', ->
      @draft.uploads = [{id: 'u2'}, @upload]
      waitsForPromise =>
        FileUploadStore._onRemoveAttachment(@upload)
        .then =>
          expect(@session.changes.add).toHaveBeenCalledWith uploads: [{id: 'u2'}]
          expect(fs.rmdir).not.toHaveBeenCalled()

    it 'removes upload and removes directory if no more uploads left dor message', ->
      @draft.uploads = [@upload]
      waitsForPromise =>
        FileUploadStore._onRemoveAttachment(@upload)
        .then =>
          expect(@session.changes.add).toHaveBeenCalledWith uploads: []
          expect(fs.rmdir).toHaveBeenCalled()


  describe '_getFileStats', ->

    it 'returns the correct stats', ->
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback(null, {size: 1234, isDirectory: -> false})
      waitsForPromise ->
        FileUploadStore._getFileStats(argsObj)
        .then ({stats}) ->
          expect(stats.size).toEqual 1234
          expect(stats.isDirectory()).toBe false

    it 'throws when there is an error reading the file', ->
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback("Error!", null)
      waitsForPromise ->
        FileUploadStore._getFileStats(argsObj)
        .then -> throw new Error('It should fail.')
        .catch (msg) ->
          expect(msg.indexOf(fpath)).toBe 0


  describe '_verifyUpload', ->

    it 'throws if upload is a directory', ->
      upload = new Upload(msgId, fpath, {isDirectory: -> true})
      waitsForPromise ->
        FileUploadStore._verifyUpload(upload)
        .then -> throw new Error('It should fail.')
        .catch (msg) ->
          expect(msg.indexOf(filename + ' is a directory')).toBe 0

    it 'throws if the file is more than 25MB', ->
      upload = new Upload(msgId, fpath, {size: 25*1000000+1, isDirectory: -> false})
      waitsForPromise ->
        FileUploadStore._verifyUpload(upload)
        .then -> throw new Error('It should fail.')
        .catch (msg) ->
          expect(msg.indexOf(filename + ' cannot')).toBe 0

    it 'resolves otherwise', ->
      upload = new Upload(msgId, fpath, {size: 1234, isDirectory: -> false})
      waitsForPromise ->
        FileUploadStore._verifyUpload(upload)
        .then (up)-> expect(up.id).toBe upload.id


  describe '_copyUpload', ->

    beforeEach ->
      stream = require 'stream'
      @upload = new Upload(msgId, fpath, {size: 1234, isDirectory: -> false}, null, uploadDir)
      @readStream = stream.Readable()
      @writeStream = stream.Writable()
      spyOn(@readStream, 'pipe')
      spyOn(fs, 'createReadStream').andReturn @readStream
      spyOn(fs, 'createWriteStream').andReturn @writeStream

    it 'copies the file correctly', ->
      waitsForPromise =>
        promise = FileUploadStore._copyUpload(@upload)
        @readStream.emit 'end'
        promise.then (up) =>
          expect(fs.createReadStream).toHaveBeenCalledWith(fpath)
          expect(fs.createWriteStream).toHaveBeenCalledWith(@upload.targetPath)
          expect(@readStream.pipe).toHaveBeenCalledWith(@writeStream)
          expect(up.id).toEqual @upload.id

    it 'throws when there is an error on the read stream', ->
      waitsForPromise =>
        promise = FileUploadStore._copyUpload(@upload)
        @readStream.emit 'error'
        promise
        .then => throw new Error('It should fail.')
        .catch (msg) =>
          expect(msg).not.toBeUndefined()

    it 'throws when there is an error on the write stream', ->
      waitsForPromise =>
        promise = FileUploadStore._copyUpload(@upload)
        @writeStream.emit 'error'
        promise
        .then => throw new Error('It should fail.')
        .catch (msg) =>
          expect(msg).not.toBeUndefined()


