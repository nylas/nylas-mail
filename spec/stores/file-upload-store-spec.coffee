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

describe 'FileUploadStore', ->
  beforeEach ->
    @draft = new Message()
    @session =
      changes:
        add: jasmine.createSpy('session.changes.add')
        commit: ->
      draft: => @draft
    spyOn(NylasEnv, "isMainWindow").andReturn(true)
    spyOn(DraftStore, "sessionForClientId").andReturn(Promise.resolve(@session))
    spyOn(FileUploadStore, "_onAttachFileError").andCallFake (msg) ->
      throw new Error(msg)
    spyOn(NylasEnv, "showOpenDialog").andCallFake (props, callback) ->
      callback(fpath)

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
      expect(args.messageClientId).toBe(msgId)
      expect(args.filePath).toBe(fpath)


  describe 'addAttachment', ->
    beforeEach ->
      @stats =  {
        size: 1234,
        isDirectory: -> false,
      }
      @upload = new Upload({
        messageClientId: msgId,
        filePath: fpath,
        stats: @stats,
        id: 'u1',
        uploadDir: uploadDir
      })
      spyOn(FileUploadStore, '_getFileStats').andCallFake => Promise.resolve(@stats)
      spyOn(FileUploadStore, '_prepareTargetDir').andCallFake => Promise.resolve()
      spyOn(FileUploadStore, '_copyUpload').andCallFake => Promise.resolve(@upload)
      spyOn(FileUploadStore, '_applySessionChanges').andCallThrough()

    it "throws if no messageClientId or path is provided", ->
      expect(-> Actions.addAttachment()).toThrow()

    it 'throws if upload is a directory', ->
      @stats = {
        isDirectory: -> true
      }
      waitsForPromise ->
        FileUploadStore._onAddAttachment({messageClientId: msgId, filePath: fpath})
        .then ->
          throw new Error('Expected test to land in catch.')
        .catch (error) ->
          expect(error.message.indexOf(filename + ' is a directory')).not.toBe(-1)

    it 'throws if the file is more than 25MB', ->
      @stats = {
        size: 25*1000000+1,
        isDirectory: -> false,
      }
      waitsForPromise ->
        FileUploadStore._onAddAttachment({messageClientId: msgId, filePath: fpath})
        .then ->
          throw new Error('Expected test to land in catch.')
        .catch (error) ->
          expect(error.message.indexOf(filename + ' cannot')).not.toBe(-1)

    it "executes the required steps and triggers", ->
      waitsForPromise ->
        FileUploadStore._onAddAttachment({messageClientId: msgId, filePath: fpath})

      runs =>
        expect(FileUploadStore._getFileStats).toHaveBeenCalled()
        expect(FileUploadStore._prepareTargetDir).toHaveBeenCalled()
        expect(FileUploadStore._copyUpload).toHaveBeenCalled()
        expect(FileUploadStore._applySessionChanges).toHaveBeenCalled()
        expect(@session.changes.add).toHaveBeenCalledWith({uploads: [@upload]})


  describe 'removeAttachment', ->
    beforeEach ->
      @upload = new Upload({
        messageClientId: msgId,
        filePath: fpath,
        stats: {
          size: 1234,
          isDirectory: -> false
        },
        id: 'u1',
        uploadDir: uploadDir
      })
      spyOn(FileUploadStore, '_deleteUpload').andCallFake => Promise.resolve(@upload)
      spyOn(fs, 'rmdir')

    it 'removes the upload from the draft', ->
      @draft.uploads = [{id: 'u2'}, @upload]
      waitsForPromise =>
        FileUploadStore._onRemoveAttachment(@upload)
        .then =>
          expect(@session.changes.add).toHaveBeenCalledWith uploads: [{id: 'u2'}]
          expect(fs.rmdir).not.toHaveBeenCalled()

    it 'calls deleteUpload to clean up the filesystem', ->
      @draft.uploads = [@upload]
      waitsForPromise =>
        FileUploadStore._onRemoveAttachment(@upload)
        .then =>
          expect(FileUploadStore._deleteUpload).toHaveBeenCalled()

  describe "when a draft is sent", ->
    it "should delete its uploads directory", ->
      spyOn(FileUploadStore, '_deleteUploadsForClientId')
      Actions.sendDraftSuccess({messageClientId: '123'})
      expect(FileUploadStore._deleteUploadsForClientId).toHaveBeenCalledWith('123')

  describe '_getFileStats', ->
    it 'returns the correct stats', ->
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback(null, {size: 1234, isDirectory: -> false})
      waitsForPromise ->
        FileUploadStore._getFileStats(fpath)
        .then (stats) ->
          expect(stats.size).toEqual 1234
          expect(stats.isDirectory()).toBe false

    it 'throws when there is an error reading the file', ->
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback("Error!", null)
      waitsForPromise ->
        FileUploadStore._getFileStats(fpath)
        .then -> throw new Error('It should fail.')
        .catch (error) ->
          expect(error.message.indexOf(fpath)).toBe 0


  describe '_copyUpload', ->
    beforeEach ->
      stream = require 'stream'
      @upload = new Upload({
        messageClientId: msgId,
        filePath: fpath,
        stats: {
          size: 1234,
          isDirectory: -> false
        },
        id: null,
        uploadDir: uploadDir
      })
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
