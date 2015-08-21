proxyquire = require 'proxyquire'
_ = require 'underscore'
NylasAPI = require '../../src/flux/nylas-api'
File = require '../../src/flux/models/file'
Task = require '../../src/flux/tasks/task'
Message = require '../../src/flux/models/message'
Actions = require '../../src/flux/actions'

AccountStore = require "../../src/flux/stores/account-store"
DraftStore = require "../../src/flux/stores/draft-store"

{APIError,
 OfflineError,
 TimeoutError} = require '../../src/flux/errors'

FileUploadTask = proxyquire "../../src/flux/tasks/file-upload-task",
  fs:
    statSync: -> {size: 1234}
    createReadStream: -> "Read Stream"
    "@noCallThru": true

test_file_paths = [
  "/fake/file.txt",
  "/fake/file.jpg"
]

noop = ->

localId = "local-id_1234"

fake_draft = new Message
  id: "draft-id_1234"
  draft: true

testResponse = '[
    {
        "content_type": "image/jpeg",
        "filename": "TestFilename.jpg",
        "id": "nylas_id_123",
        "account_id": "ns-id",
        "object": "file",
        "size": 19013
    }
]'
equivalentFile = (new File).fromJSON(JSON.parse(testResponse)[0])

DATE = 1433963615918

describe "FileUploadTask", ->
  beforeEach ->
    spyOn(Date, "now").andReturn DATE

    @uploadData =
      startDate: DATE
      messageLocalId: localId
      filePath: test_file_paths[0]
      fileSize: 1234
      fileName: "file.txt"
    bytesUploaded: 0

    @task = new FileUploadTask(test_file_paths[0], localId)

    @req = jasmine.createSpyObj('req', ['abort'])
    @simulateRequestSuccessImmediately = false
    @simulateRequestSuccess = null
    @simulateRequestFailure = null

    spyOn(NylasAPI, 'makeRequest').andCallFake (reqParams) =>
      new Promise (resolve, reject) =>
        reqParams.started?(@req)
        @simulateRequestSuccess = (data) =>
          reqParams.success?(data)
          resolve(data)
        @simulateRequestFailure = (err) =>
          reqParams.error?(err)
          reject(err)
        if @simulateRequestSuccessImmediately
          @simulateRequestSuccess(testResponse)

  it "rejects if not initialized with a path name", (done) ->
    waitsForPromise ->
      (new FileUploadTask).performLocal().catch (err) ->
        expect(err instanceof Error).toBe true

  it "rejects if not initialized with a messageLocalId", ->
    waitsForPromise ->
      (new FileUploadTask(test_file_paths[0])).performLocal().catch (err) ->
        expect(err instanceof Error).toBe true

  it 'initializes the upload start', ->
    task = new FileUploadTask(test_file_paths[0], localId)
    expect(task._startDate).toBe DATE

  it "notifies when the task locally starts", ->
    spyOn(Actions, "uploadStateChanged")

    waitsForPromise =>
      @task.performLocal().then =>
        data = _.extend @uploadData, state: "pending", bytesUploaded: 0
        dataReceived = Actions.uploadStateChanged.calls[0].args[0]
        expect(_.isMatch(dataReceived, data)).toBe(true)

  describe "when the remote API request fails with an API Error", ->
    beforeEach ->
      @taskExitStatus = null
      @runWithError = (simulatedError) =>
        runs ->
          @task.performRemote().catch (err) ->
            console.log(err)
          .then (status) =>
            @taskExitStatus = status

        waitsFor ->
          @simulateRequestFailure
        runs ->
          spyOn(@task, "_getBytesUploaded").andReturn(0)
          spyOn(Actions, "uploadStateChanged")
          @simulateRequestFailure(simulatedError)
        waitsFor ->
          Actions.uploadStateChanged.callCount > 0
          advanceClock(100)

    describe "if the error is permanent", ->
      beforeEach ->
        @runWithError(new APIError(statusCode: 400))

      it "should broadcast `failed` if the error is permanent", ->
        runs ->
          data = _.extend(@uploadData, {state: "failed", bytesUploaded: 0})
          dataReceived = Actions.uploadStateChanged.calls[0].args[0]
          expect(_.isMatch(dataReceived, data)).toBe(true)

      it "should resolve with `finished`", ->
        runs ->
          expect(@taskExitStatus).toBe(Task.Status.Finished)

    describe "if the error is temporary", ->
      beforeEach ->
        @runWithError(new APIError(statusCode: 0))

      it "should resolve with `retry`", ->
        runs ->
          expect(@taskExitStatus).toBe(Task.Status.Retry)

    describe "if the request was cancelled", ->
      beforeEach ->
        @runWithError(new APIError(statusCode: NylasAPI.CancelledErrorCode))

      it "should broadcast `aborted` if the upload was cancelled", ->
        runs ->
          data = _.extend(@uploadData, {state: "aborted", bytesUploaded: 0})
          dataReceived = Actions.uploadStateChanged.calls[0].args[0]
          expect(_.isMatch(dataReceived, data)).toBe(true)

  describe "when the remote API request succeeds", ->
    beforeEach ->
      @testFiles = []
      @changes = []
      @simulateRequestSuccessImmediately = true

      spyOn(Actions, "uploadStateChanged")
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
          dataReceived = Actions.uploadStateChanged.calls[0].args[0]
          expect(_.isMatch(dataReceived, data)).toBe(true)

    it "should start an API request", ->
      waitsForPromise => @task.performRemote().then ->
        options = NylasAPI.makeRequest.mostRecentCall.args[0]
        expect(options.path).toBe("/files")
        expect(options.accountId).toBe("test_account_id")
        expect(options.method).toBe('POST')
        expect(options.formData.file.value).toBe("Read Stream")

    it "attaches the file to the draft", ->
      waitsForPromise => @task.performRemote().then =>
        expect(@changes).toEqual [equivalentFile]

    describe "file upload notifications", ->
      it "correctly fires the fileUploaded action", ->
        spyOn(@task, "_getBytesUploaded").andReturn(1000)
        spyOn(Actions, "fileUploaded")
        @task.performRemote()
        advanceClock()
        @simulateRequestSuccess()
        advanceClock()
        Actions.fileUploaded.calls.length > 0

        uploadDataExpected = _.extend {}, @uploadData,
          state: "completed"
          bytesUploaded: 1000

        [{file, uploadData}] = Actions.fileUploaded.calls[0].args
        expect(file).toEqual(equivalentFile)
        expect(_.isMatch(uploadData, uploadDataExpected)).toBe(true)

    describe "when attaching a lot of files", ->
      it "attaches them all to the draft", ->
        t1 = new FileUploadTask("1.a", localId)
        t2 = new FileUploadTask("2.b", localId)
        t3 = new FileUploadTask("3.c", localId)
        t4 = new FileUploadTask("4.d", localId)

        @simulateRequestSuccessImmediately = true
        waitsForPromise => Promise.all([
          t1.performRemote()
          t2.performRemote()
          t3.performRemote()
          t4.performRemote()
        ]).then =>
          expect(@changes.length).toBe 4

  describe "cancel", ->
    it "should not do anything if the request has finished", ->
      runs =>
        @task.performRemote()
      waitsFor =>
        @simulateRequestSuccess
      runs =>
        @simulateRequestSuccess(testResponse)
      waitsFor =>
        @task.req is null
      runs =>
        @task.cancel()
        expect(@req.abort).not.toHaveBeenCalled()

    it "should cancel the request if it's in flight", ->
      spyOn(Actions, "uploadStateChanged")

      @task.performRemote()
      advanceClock()
      @task.cancel()
      advanceClock()

      expect(@req.abort).toHaveBeenCalled()
