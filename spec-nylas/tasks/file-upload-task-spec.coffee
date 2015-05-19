proxyquire = require 'proxyquire'
_ = require 'underscore-plus'
NylasAPI = require '../../src/flux/nylas-api'
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

testResponse = '[
    {
        "content_type": "image/jpeg",
        "filename": "TestFilename.jpg",
        "id": "nylas_id_123",
        "namespace_id": "ns-id",
        "object": "file",
        "size": 19013
    }
]'
equivalentFile = (new File).fromJSON(JSON.parse(testResponse)[0])

uploadData =
  messageLocalId: localId
  filePath: test_file_paths[0]
  fileSize: 1234
  fileName: "file.txt"
  bytesUploaded: 0

describe "FileUploadTask", ->
  it "rejects if not initialized with a path name", (done) ->
    waitsForPromise ->
      (new FileUploadTask).performLocal().catch (err) ->
        expect(err instanceof Error).toBe true

  it "rejects if not initialized with a messageLocalId", ->
    waitsForPromise ->
      (new FileUploadTask(test_file_paths[0])).performLocal().catch (err) ->
        expect(err instanceof Error).toBe true

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
      spyOn(NylasAPI, 'makeRequest').andCallFake (reqParams) =>
        reqParams.success(testResponse) if reqParams.success
        return @req

    it "notifies when the task starts remote", ->
      waitsForPromise =>
        @task.performLocal().then ->
          data = _.extend uploadData, state: "pending"
          expect(Actions.uploadStateChanged).toHaveBeenCalledWith data

    it "should start an API request", ->
      waitsForPromise => @task.performRemote().then ->
        options = NylasAPI.makeRequest.mostRecentCall.args[0]
        expect(options.path).toBe("/n/nsid/files")
        expect(options.method).toBe('POST')
        expect(options.formData.file.value).toBe("Read Stream")

    it "passes the file to the completed notification function", ->
      spyOn(@task, "_completedNotification").andReturn(100)
      waitsForPromise => @task.performRemote().then =>
        expect(@task._completedNotification).toHaveBeenCalledWith(equivalentFile)

    describe "file upload notifications", ->
      beforeEach ->
        @fileUploadFiredLast = false
        spyOn(Actions, "attachFileComplete").andCallFake =>
          @fileUploadFiredLast = false
        spyOn(Actions, "fileUploaded").andCallFake =>
          @fileUploadFiredLast = true
        spyOn(@task, "_getBytesUploaded").andReturn(1000)

        runs =>
          @task.performRemote()
          advanceClock(2000)
        waitsFor ->
          Actions.fileUploaded.calls.length > 0

      it "calls the `attachFileComplete` action first", ->
        runs ->
          expect(@fileUploadFiredLast).toBe true

      it "correctly fires the attachFileComplete action", ->
        runs ->
          expect(Actions.attachFileComplete).toHaveBeenCalledWith
            file: equivalentFile
            messageLocalId: localId

      it "correctly fires the fileUploaded action", ->
        runs ->
          expect(Actions.fileUploaded).toHaveBeenCalledWith
            uploadData: _.extend {}, uploadData,
              state: "completed"
              bytesUploaded: 1000

  describe "cleanup", ->
    it "should not do anything if the request has finished", ->
      req = jasmine.createSpyObj('req', ['abort'])
      reqSuccess = null
      spyOn(NylasAPI, 'makeRequest').andCallFake (reqParams) ->
        reqSuccess = reqParams.success
        req

      @task.performRemote()
      reqSuccess(testResponse)
      @task.cleanup()
      expect(req.abort).not.toHaveBeenCalled()

    it "should cancel the request if it's in flight", ->
      req = jasmine.createSpyObj('req', ['abort'])
      spyOn(NylasAPI, 'makeRequest').andCallFake (reqParams) -> req
      spyOn(Actions, "uploadStateChanged")

      @task.performRemote()
      @task.cleanup()

      expect(req.abort).toHaveBeenCalled()
      data = _.extend uploadData,
        state: "aborted"
        bytesUploaded: 0
      expect(Actions.uploadStateChanged).toHaveBeenCalledWith(data)
