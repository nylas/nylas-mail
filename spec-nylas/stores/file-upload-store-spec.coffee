File = require '../../src/flux/models/file'
Actions = require '../../src/flux/actions'
FileUploadStore = require '../../src/flux/stores/file-upload-store'

msgId = "local-123"
fpath = "/foo/bar/test123.jpg"

describe 'FileUploadStore', ->
  beforeEach ->
    @file = new File
      id: "id_123"
      filename: "test123.jpg"
      size: 12345
    @uploadData =
      uploadId: 123
      messageLocalId: msgId
      filePath: fpath
      fileSize: 12345

    spyOn(atom, "showOpenDialog").andCallFake (props, callback) ->
      callback(fpath)

    spyOn(Actions, "queueTask")

  describe 'when a user wants to attach a file', ->
    it "throws if the message id is blank", ->
      expect( -> Actions.attachFile()).toThrow()

    it "throws if the message id is blank", ->
      spyOn(Actions, "attachFilePath")
      Actions.attachFile messageLocalId: msgId
      expect(atom.showOpenDialog).toHaveBeenCalled()
      expect(Actions.attachFilePath).toHaveBeenCalled()
      args = Actions.attachFilePath.calls[0].args[0]
      expect(args.messageLocalId).toBe msgId
      expect(args.path).toBe fpath

  describe 'when a user selected the file to attach', ->
    it "throws if the message id is blank", ->
      expect( -> Actions.attachFilePath()).toThrow()

    it 'Creates a new file upload task', ->
      Actions.attachFilePath
        messageLocalId: msgId
        path: fpath
      expect(Actions.queueTask).toHaveBeenCalled()
      t = Actions.queueTask.calls[0].args[0]
      expect(t.filePath).toBe fpath
      expect(t.messageLocalId).toBe msgId

  describe 'when an uploading file is aborted', ->
    it "dequeues the matching task", ->
      spyOn(Actions, "dequeueMatchingTask")
      Actions.abortUpload(@uploadData)
      expect(Actions.dequeueMatchingTask).toHaveBeenCalled()
      arg = Actions.dequeueMatchingTask.calls[0].args[0]
      expect(arg).toEqual
        type: "FileUploadTask"
        matching: filePath: fpath

  describe 'when upload state changes', ->
    it 'updates the uploadData', ->
      Actions.uploadStateChanged(@uploadData)
      expect(FileUploadStore._fileUploads[123]).toBe @uploadData

  describe 'when a file has been uploaded', ->
    it 'adds to the linked files and removes from uploads', ->
      FileUploadStore._fileUploads[123] = @uploadData
      Actions.fileUploaded
        file: @file
        uploadData: @uploadData
      expect(FileUploadStore._linkedFiles["id_123"]).toBe @uploadData
      expect(FileUploadStore._fileUploads[123]).not.toBeDefined()

  describe 'when a file has been aborted', ->
    it 'removes it from the uploads', ->
      FileUploadStore._fileUploads[123] = @uploadData
      Actions.fileAborted(@uploadData)
      expect(FileUploadStore._fileUploads[123]).not.toBeDefined()
