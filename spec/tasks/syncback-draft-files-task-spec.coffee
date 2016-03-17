_ = require 'underscore'
fs = require 'fs'
{APIError,
 Actions,
 DatabaseStore,
 DatabaseTransaction,
 Message,
 Contact,
 Task,
 TaskQueue,
 SyncbackDraftFilesTask,
 NylasAPI,
 SoundRegistry} = require 'nylas-exports'

DBt = DatabaseTransaction.prototype

describe "SyncbackDraftFilesTask", ->
  describe "with uploads", ->
    beforeEach ->
      @uploads = [
        {targetPath: '/test-file-1.png', size: 100},
        {targetPath: '/test-file-2.png', size: 100}
      ]
      @draft = new Message
        version: 1
        clientId: 'client-id'
        accountId: TEST_ACCOUNT_ID
        from: [new Contact(email: TEST_ACCOUNT_EMAIL)]
        subject: 'New Draft'
        draft: true
        body: 'hello world'
        uploads: [].concat(@uploads)

      @task = new SyncbackDraftFilesTask(@draft.clientId)

      @resolves = []
      @resolveAll = =>
        resolve() for resolve in @resolves
        @resolves = []
        advanceClock()

      spyOn(DBt, 'persistModel')
      spyOn(fs, 'createReadStream').andReturn "stub"
      spyOn(NylasAPI, 'makeRequest').andCallFake (options) =>
        response = @response

        if options.path is '/files'
          response = JSON.stringify([{
            id: '1234'
            account_id: TEST_ACCOUNT_ID
            filename: options.formData.file.options.filename
          }])

        new Promise (resolve, reject) =>
          @resolves.push =>
            options.success?(response)
            resolve(response)

      spyOn(DatabaseStore, 'run').andCallFake =>
        Promise.resolve(@draft)

    it "should begin file uploads and not resolve until they complete", ->
      taskPromise = @task.performRemote()
      advanceClock()

      # uploads should be queued, but not the send
      expect(NylasAPI.makeRequest.callCount).toEqual(2)
      expect(NylasAPI.makeRequest.calls[0].args[0].formData).toEqual({ file : { value : 'stub', options : { filename : 'test-file-1.png' } } })
      expect(NylasAPI.makeRequest.calls[1].args[0].formData).toEqual({ file : { value : 'stub', options : { filename : 'test-file-2.png' } } })

      # finish all uploads
      expect(taskPromise.isFulfilled()).toBe(false)
      @resolveAll()
      expect(taskPromise.isFulfilled()).toBe(true)

    it "should update the draft, removing uploads and adding files", ->
      taskPromise = @task.performRemote()
      advanceClock()
      @resolveAll()
      advanceClock()
      expect(DBt.persistModel).toHaveBeenCalled()
      draft = DBt.persistModel.mostRecentCall.args[0]
      expect(draft.files.length).toBe(2)
      expect(draft.uploads.length).toBe(0)

    it "should not interfere with other uploads added to the draft during task execution", ->
      taskPromise = @task.performRemote()
      advanceClock()
      @draft.uploads.push({targetPath: '/test-file-3.png', size: 100})
      @resolveAll()
      advanceClock()
      expect(DBt.persistModel).toHaveBeenCalled()
      draft = DBt.persistModel.mostRecentCall.args[0]
      expect(draft.files.length).toBe(2)
      expect(draft.uploads.length).toBe(1)
