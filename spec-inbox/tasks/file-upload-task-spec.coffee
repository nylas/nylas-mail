proxyquire = require 'proxyquire'
_ = require 'underscore-plus'
File = require '../../src/flux/models/file'
Message = require '../../src/flux/models/message'
Actions = require '../../src/flux/actions'

NamespaceStore = require "../../src/flux/stores/namespace-store"

FileUploadTask = proxyquire "../../src/flux/tasks/file-upload-task",
  fs:
    statSync: -> {size: 1234}
    createReadStream: -> "Read Stream"
    "@noCallThru": true

test_file_paths = [
  "/fake/file.txt",
  "/fake/file.jpg"
]

localId = "local-id_1234"

fake_draft = new Message
  id: "draft-id_1234"
  draft: true

fileJSON =
  id: "file_id_123"

uploadData =
  messageLocalId: localId
  filePath: test_file_paths[0]
  fileSize: 1234
  fileName: "file.txt"
  bytesUploaded: 0

describe "FileUploadTask", ->
  it "rejects if not initialized with a path name", (done) ->
    waitsForPromise shouldReject: true, ->
      (new FileUploadTask).performLocal()

  it "rejects if not initialized with a messageLocalId", ->
    waitsForPromise shouldReject: true, ->
      (new FileUploadTask(test_file_paths[0])).performLocal()

  beforeEach ->
    @task = new FileUploadTask(test_file_paths[0], localId)

  it "notifies when the task locally starts", ->
    spyOn(Actions, "uploadStateChanged")

    waitsForPromise =>
      @task.performLocal().then ->
        data = _.extend uploadData, state: "pending"
        expect(Actions.uploadStateChanged).toHaveBeenCalledWith data

  it "notifies when the file upload fails", ->
    spyOn(Actions, "uploadStateChanged")
    spyOn(@task, "_getBytesUploaded").andReturn(0)
    @task._rollbackLocal()
    data = _.extend uploadData, state: "failed"
    expect(Actions.uploadStateChanged).toHaveBeenCalledWith(data)

  describe "When successfully calling remote", ->
    beforeEach ->
      spyOn(Actions, "uploadStateChanged")
      @req = jasmine.createSpyObj('req', ['abort'])
      spyOn(atom.inbox, 'makeRequest').andCallFake (reqParams) =>
        reqParams.success([fileJSON]) if reqParams.success
        return @req

    it "notifies when the task starts remote", ->
      waitsForPromise =>
        @task.performLocal().then ->
          data = _.extend uploadData, state: "pending"
          expect(Actions.uploadStateChanged).toHaveBeenCalledWith data

    it "should start an API request", ->
      waitsForPromise => @task.performRemote().then ->
        options = atom.inbox.makeRequest.mostRecentCall.args[0]
        expect(options.path).toBe("/n/nsid/files")
        expect(options.method).toBe('POST')
        expect(options.formData.file.value).toBe("Read Stream")

    it "can abort the upload with the full file path", ->
      spyOn(@task, "_getBytesUploaded").andReturn(100)
      waitsForPromise => @task.performRemote().then =>
        @task.abort()
        expect(@req.abort).toHaveBeenCalled()
        data = _.extend uploadData,
          state: "aborted"
          bytesUploaded: 100
        expect(Actions.uploadStateChanged).toHaveBeenCalledWith(data)

    it "notifies when the file successfully uploaded", ->
      spyOn(@task, "_completedNotification").andReturn(100)
      waitsForPromise => @task.performRemote().then =>
        file = (new File).fromJSON(fileJSON)
        expect(@task._completedNotification).toHaveBeenCalledWith(file)
