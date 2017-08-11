fs = require 'fs'
path = require 'path'
{shell} = require 'electron'
File = require('../../src/flux/models/file').default
Message = require('../../src/flux/models/message').default
AttachmentStore = require('../../src/flux/stores/attachment-store').default
{Download} = require('../../src/flux/stores/attachment-store')
AccountStore = require('../../src/flux/stores/account-store').default


xdescribe 'AttachmentStoreSpecs', ->

  describe "AttachmentStore", ->
    beforeEach ->
      account = AccountStore.accounts()[0]

      spyOn(shell, 'showItemInFolder')
      spyOn(shell, 'openItem')
      @testfile = new File({
        accountId: account.id,
        filename: '123.png',
        contentType: 'image/png',
        id: "id",
        size: 100
      })
      @testdownload = new Download({
        accountId: account.id,
        state : 'unknown',
        fileId : 'id',
        percent : 0,
        filename : '123.png',
        filesize : 100,
        targetPath : '/Users/testuser/.nylas-mail/downloads/id/123.png'
      })

      AttachmentStore._downloads = {}
      AttachmentStore._downloadDirectory = "/Users/testuser/.nylas-mail/downloads"
      spyOn(AttachmentStore, '_generatePreview').andReturn(Promise.resolve())

    describe "pathForFile", ->
      it "should return path within the download directory with the file id and displayName", ->
        f = new File(filename: '123.png', contentType: 'image/png', id: 'id')
        spyOn(f, 'displayName').andCallThrough()
        expect(AttachmentStore.pathForFile(f)).toBe("/Users/testuser/.nylas-mail/downloads/id/123.png")
        expect(f.displayName).toHaveBeenCalled()

      it "should return unique paths for identical filenames with different IDs", ->
        f1 = new File(filename: '123.png', contentType: 'image/png', id: 'id1')
        f2 = new File(filename: '123.png', contentType: 'image/png', id: 'id2')
        expect(AttachmentStore.pathForFile(f1)).toBe("/Users/testuser/.nylas-mail/downloads/id1/123.png")
        expect(AttachmentStore.pathForFile(f2)).toBe("/Users/testuser/.nylas-mail/downloads/id2/123.png")

    it "should escape the displayName if it contains path separator characters", ->
      f1 = new File(filename: "static#{path.sep}b#{path.sep}a.jpg", contentType: 'image/png', id: 'id1')
      expect(AttachmentStore.pathForFile(f1)).toBe("/Users/testuser/.nylas-mail/downloads/id1/static-b-a.jpg")

      f1 = new File(filename: "my:file ? Windows /hates/ me :->.jpg", contentType: 'image/png', id: 'id1')
      expect(AttachmentStore.pathForFile(f1)).toBe("/Users/testuser/.nylas-mail/downloads/id1/my-file - Windows -hates- me ---.jpg")

    describe "_checkForDownloadedFile", ->
      it "should return true if the file exists at the path and is the right size", ->
        f = new File(filename: '123.png', contentType: 'image/png', id: "id", size: 100)
        spyOn(fs, 'statAsync').andCallFake (path) ->
          Promise.resolve({size: 100})
        waitsForPromise ->
          AttachmentStore._checkForDownloadedFile(f).then (downloaded) ->
            expect(downloaded).toBe(true)

      it "should return false if the file does not exist", ->
        f = new File(filename: '123.png', contentType: 'image/png', id: "id", size: 100)
        spyOn(fs, 'statAsync').andCallFake (path) ->
          Promise.reject(new Error("File does not exist"))
        waitsForPromise ->
          AttachmentStore._checkForDownloadedFile(f).then (downloaded) ->
            expect(downloaded).toBe(false)

      it "should return false if the file is too small", ->
        f = new File(filename: '123.png', contentType: 'image/png', id: "id", size: 100)
        spyOn(fs, 'statAsync').andCallFake (path) ->
          Promise.resolve({size: 50})
        waitsForPromise ->
          AttachmentStore._checkForDownloadedFile(f).then (downloaded) ->
            expect(downloaded).toBe(false)

    describe "_ensureFile", ->
      beforeEach ->
        spyOn(Download.prototype, 'run').andCallFake -> Promise.resolve(@)
        spyOn(AttachmentStore, '_prepareFolder').andCallFake -> Promise.resolve(true)

      it "should make sure that the download file path exists", ->
        waitsForPromise =>
          AttachmentStore._ensureFile(@testfile).then ->
            expect(AttachmentStore._prepareFolder).toHaveBeenCalled()

      it "should return the promise returned by download.run if the download already exists", ->
        existing =
          fileId: @testfile.id
          run: jasmine.createSpy('existing.run').andCallFake ->
            Promise.resolve(existing)
        AttachmentStore._downloads[@testfile.id] = existing

        promise = AttachmentStore._ensureFile(@testfile)
        expect(promise instanceof Promise).toBe(true)
        waitsForPromise ->
          promise.then ->
            expect(existing.run).toHaveBeenCalled()

      describe "when the downloaded file exists", ->
        beforeEach ->
          spyOn(AttachmentStore, '_checkForDownloadedFile').andCallFake ->
            Promise.resolve(true)

        it "should resolve with a Download without calling download.run", ->
          waitsForPromise =>
            AttachmentStore._ensureFile(@testfile).then (download) ->
              expect(Download.prototype.run).not.toHaveBeenCalled()
              expect(download instanceof Download).toBe(true)
              expect(download.data()).toEqual({
                state : 'finished',
                fileId : 'id',
                percent : 0,
                filename : '123.png',
                filesize : 100,
                targetPath : '/Users/testuser/.nylas-mail/downloads/id/123.png'
              })

      describe "when the downloaded file does not exist", ->
        beforeEach ->
          spyOn(AttachmentStore, '_checkForDownloadedFile').andCallFake ->
            Promise.resolve(false)

        it "should register the download with the right attributes", ->
          AttachmentStore._ensureFile(@testfile)
          advanceClock(0)
          expect(AttachmentStore.getDownloadDataForFile(@testfile.id)).toEqual({
            state : 'unstarted',fileId : 'id',
            percent : 0,
            filename : '123.png',
            filesize : 100,
            targetPath : '/Users/testuser/.nylas-mail/downloads/id/123.png'
          })

        it "should call download.run", ->
          waitsForPromise =>
            AttachmentStore._ensureFile(@testfile)
          runs ->
            expect(Download.prototype.run).toHaveBeenCalled()

        it "should resolve with a Download", ->
          waitsForPromise =>
            AttachmentStore._ensureFile(@testfile).then (download) ->
              expect(download instanceof Download).toBe(true)
              expect(download.data()).toEqual({
                state : 'unstarted',
                fileId : 'id',
                percent : 0,
                filename : '123.png',
                filesize : 100,
                targetPath : '/Users/testuser/.nylas-mail/downloads/id/123.png'
              })

    describe "_fetch", ->
      it "should call through to startDownload", ->
        spyOn(AttachmentStore, '_ensureFile').andCallFake ->
          Promise.resolve(@testdownload)
        AttachmentStore._fetch(@testfile)
        expect(AttachmentStore._ensureFile).toHaveBeenCalled()

      it "should fail silently since it's called passively", ->
        spyOn(AttachmentStore, '_presentError')
        spyOn(AttachmentStore, '_ensureFile').andCallFake =>
          Promise.reject(@testdownload)
        AttachmentStore._fetch(@testfile)
        expect(AttachmentStore._presentError).not.toHaveBeenCalled()

    describe "_fetchAndOpen", ->
      it "should open the file once it's been downloaded", ->
        @savePath = "/Users/imaginary/.nylas-mail/Downloads/a.png"
        download = {targetPath: @savePath}
        downloadResolve = null

        spyOn(AttachmentStore, '_ensureFile').andCallFake =>
          new Promise (resolve, reject) ->
            downloadResolve = resolve

        AttachmentStore._fetchAndOpen(@testfile)
        expect(shell.openItem).not.toHaveBeenCalled()
        downloadResolve(download)
        advanceClock(100)
        expect(shell.openItem).toHaveBeenCalledWith(@savePath)

      it "should open an error if the download fails", ->
        spyOn(AttachmentStore, '_presentError')
        spyOn(AttachmentStore, '_ensureFile').andCallFake =>
          Promise.reject(@testdownload)
        AttachmentStore._fetchAndOpen(@testfile)
        advanceClock(1)
        expect(AttachmentStore._presentError).toHaveBeenCalled()

    describe "_fetchAndSave", ->
      beforeEach ->
        @userSelectedPath = "/Users/imaginary/.nylas-mail/Downloads/b.png"
        spyOn(NylasEnv, 'showSaveDialog').andCallFake (options, callback) => callback(@userSelectedPath)

      it "should open a save dialog and prompt the user to choose a download path", ->
        spyOn(AttachmentStore, '_ensureFile').andCallFake =>
          new Promise (resolve, reject) -> # never resolve
        AttachmentStore._fetchAndSave(@testfile)
        expect(NylasEnv.showSaveDialog).toHaveBeenCalled()
        expect(AttachmentStore._ensureFile).toHaveBeenCalledWith(@testfile)

      it "should open an error if the download fails", ->
        spyOn(AttachmentStore, '_presentError')
        spyOn(AttachmentStore, '_ensureFile').andCallFake =>
          Promise.reject(@testdownload)
        AttachmentStore._fetchAndSave(@testfile)
        advanceClock(1)
        expect(AttachmentStore._presentError).toHaveBeenCalled()

      describe "when the user confirms a path", ->
        beforeEach ->
          @download = {targetPath: 'bla'}
          @onEndEventCallback = null
          streamStub =
            pipe: ->
            on: (eventName, eventCallback) =>
              @onEndEventCallback = eventCallback

          spyOn(AttachmentStore, '_ensureFile').andCallFake =>
            Promise.resolve(@download)
          spyOn(fs, 'createReadStream').andReturn(streamStub)
          spyOn(fs, 'createWriteStream')

        it "should copy the file to the download path after it's been downloaded and open it after the stream has ended", ->
          AttachmentStore._fetchAndSave(@testfile)
          advanceClock(1)
          expect(fs.createReadStream).toHaveBeenCalledWith(@download.targetPath)
          expect(shell.showItemInFolder).not.toHaveBeenCalled()
          @onEndEventCallback()
          advanceClock(1)

        it "should show file in folder if download path differs from previous download path", ->
          spyOn(AttachmentStore, '_saveDownload').andCallFake =>
            Promise.resolve(@testfile)
          NylasEnv.savedState.lastDownloadDirectory = null
          @userSelectedPath = "/Users/imaginary/.nylas-mail/Another Random Folder/file.jpg"
          AttachmentStore._fetchAndSave(@testfile)
          advanceClock(1)
          expect(shell.showItemInFolder).toHaveBeenCalledWith(@userSelectedPath)

        it "should not show the file in the folder if the download path is the previous download path", ->
          spyOn(AttachmentStore, '_saveDownload').andCallFake =>
            Promise.resolve(@testfile)
          @userSelectedPath = "/Users/imaginary/.nylas-mail/Another Random Folder/123.png"
          NylasEnv.savedState.lastDownloadDirectory = "/Users/imaginary/.nylas-mail/Another Random Folder"
          AttachmentStore._fetchAndSave(@testfile)
          advanceClock(1)
          expect(shell.showItemInFolder).not.toHaveBeenCalled()

        it "should update the NylasEnv.savedState.lastDownloadDirectory if is has changed", ->
          spyOn(AttachmentStore, '_saveDownload').andCallFake =>
            Promise.resolve(@testfile)
          NylasEnv.savedState.lastDownloadDirectory = null
          @userSelectedPath = "/Users/imaginary/.nylas-mail/Another Random Folder/file.jpg"
          AttachmentStore._fetchAndSave(@testfile)
          advanceClock(1)
          expect(NylasEnv.savedState.lastDownloadDirectory).toEqual('/Users/imaginary/.nylas-mail/Another Random Folder')

        describe "file extensions", ->
          it "should allow the user to save the file with a different extension", ->
            @userSelectedPath = "/Users/imaginary/.nylas-mail/Downloads/b-changed.tiff"
            AttachmentStore._fetchAndSave(@testfile)
            advanceClock(1)
            expect(fs.createWriteStream).toHaveBeenCalledWith(@userSelectedPath)

          it "should restore the extension if the user removed it entirely, because it's usually an accident", ->
            @userSelectedPath = "/Users/imaginary/.nylas-mail/Downloads/b-changed"
            AttachmentStore._fetchAndSave(@testfile)
            advanceClock(1)
            expect(fs.createWriteStream).toHaveBeenCalledWith("#{@userSelectedPath}.png")

    describe "_abortFetchFile", ->
      beforeEach ->
        @download =
          ensureClosed: jasmine.createSpy('abort')
          fileId: @testfile.id
        AttachmentStore._downloads[@testfile.id] = @download

      it "should cancel the download for the provided file", ->
        spyOn(fs, 'exists').andCallFake (path, callback) -> callback(true)
        spyOn(fs, 'unlink')
        AttachmentStore._abortFetchFile(@testfile)
        expect(fs.unlink).toHaveBeenCalled()
        expect(@download.ensureClosed).toHaveBeenCalled()

      it "should not try to delete the file if doesn't exist", ->
        spyOn(fs, 'exists').andCallFake (path, callback) -> callback(false)
        spyOn(fs, 'unlink')
        AttachmentStore._abortFetchFile(@testfile)
        expect(fs.unlink).not.toHaveBeenCalled()
        expect(@download.ensureClosed).toHaveBeenCalled()
