proxyquire = require 'proxyquire'
_ = require 'underscore'
NylasAPI = require '../../src/flux/nylas-api'
File = require '../../src/flux/models/file'
Message = require '../../src/flux/models/message'
Actions = require '../../src/flux/actions'

NamespaceStore = require "../../src/flux/stores/namespace-store"
DraftStore = require "../../src/flux/stores/draft-store"

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

DATE = 1433963615918

describe "FileUploadTask", ->
  beforeEach ->
    spyOn(Date, "now").andReturn DATE
    spyOn(FileUploadTask, "idGen").andReturn 3
    @uploadData =
      uploadId: 3
      startedUploadingAt: DATE
      messageLocalId: localId
      filePath: test_file_paths[0]
      fileSize: 1234
      fileName: "file.txt"
    bytesUploaded: 0

    @task = new FileUploadTask(test_file_paths[0], localId)

  it "rejects if not initialized with a path name", (done) ->
    waitsForPromise ->
      (new FileUploadTask).performLocal().catch (err) ->
        expect(err instanceof Error).toBe true

  it "rejects if not initialized with a messageLocalId", ->
    waitsForPromise ->
      (new FileUploadTask(test_file_paths[0])).performLocal().catch (err) ->
        expect(err instanceof Error).toBe true

  it 'initializes an uploadId', ->
    task = new FileUploadTask(test_file_paths[0], localId)
    expect(task._uploadId).toBeGreaterThan 2

  it 'initializes the upload start', ->
    task = new FileUploadTask(test_file_paths[0], localId)
    expect(task._startedUploadingAt).toBe DATE

  it "notifies when the task locally starts", ->
    spyOn(Actions, "uploadStateChanged")

    waitsForPromise =>
      @task.performLocal().then =>
        data = _.extend @uploadData, state: "pending", bytesUploaded: 0
        expect(Actions.uploadStateChanged).toHaveBeenCalledWith data

  it "notifies when the file upload fails", ->
    spyOn(Actions, "uploadStateChanged")
    spyOn(@task, "_getBytesUploaded").andReturn(0)
    @task._rollbackLocal()
    data = _.extend @uploadData, state: "failed", bytesUploaded: 0
    expect(Actions.uploadStateChanged).toHaveBeenCalledWith(data)

  describe "When successfully calling remote", ->
    beforeEach ->
      spyOn(Actions, "uploadStateChanged")
      @req = jasmine.createSpyObj('req', ['abort'])
      spyOn(NylasAPI, 'makeRequest').andCallFake (reqParams) =>
        reqParams.success(testResponse) if reqParams.success
        return @req
      @testFiles = []
      @changes = []
      spyOn(DraftStore, "sessionForLocalId").andCallFake =>
        Promise.resolve(
          draft: => files: @testFiles
          changes:
            add: ({files}) => @changes = @changes.concat(files)
            commit: -> Promise.resolve()
        )

    it "notifies when the task starts remote", ->
      waitsForPromise =>
        @task.performLocal().then =>
          data = _.extend @uploadData, state: "pending", bytesUploaded: 0
          expect(Actions.uploadStateChanged).toHaveBeenCalledWith data

    it "should start an API request", ->
      waitsForPromise => @task.performRemote().then ->
        options = NylasAPI.makeRequest.mostRecentCall.args[0]
        expect(options.path).toBe("/n/nsid/files")
        expect(options.method).toBe('POST')
        expect(options.formData.file.value).toBe("Read Stream")

    it "attaches the file to the draft", ->
      waitsForPromise => @task.performRemote().then =>
        expect(@changes).toEqual [equivalentFile]

    describe "file upload notifications", ->
      beforeEach ->
        spyOn(Actions, "fileUploaded")
        spyOn(@task, "_getBytesUploaded").andReturn(1000)

        runs =>
          @task.performRemote()
          advanceClock(2000)
        waitsFor ->
          Actions.fileUploaded.calls.length > 0

      it "correctly fires the fileUploaded action", ->
        runs =>
          expect(Actions.fileUploaded).toHaveBeenCalledWith
            file: equivalentFile
            uploadData: _.extend {}, @uploadData,
              state: "completed"
              bytesUploaded: 1000

    describe "when attaching a lot of files", ->
      it "attaches them all to the draft", ->
        t1 = new FileUploadTask("1.a", localId)
        t2 = new FileUploadTask("2.b", localId)
        t3 = new FileUploadTask("3.c", localId)
        t4 = new FileUploadTask("4.d", localId)

        waitsForPromise => Promise.all([
          t1.performRemote()
          t2.performRemote()
          t3.performRemote()
          t4.performRemote()
        ]).then =>
          expect(@changes.length).toBe 4

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
      data = _.extend @uploadData,
        state: "aborted"
        bytesUploaded: 0
      expect(Actions.uploadStateChanged).toHaveBeenCalledWith(data)
