fs = require 'fs'
shell = require 'shell'
NylasAPI = require '../../src/flux/nylas-api'
File = require '../../src/flux/models/file'
FileDownloadStore = require '../../src/flux/stores/file-download-store'
Download = FileDownloadStore.Download

describe "FileDownloadStore.Download", ->
  beforeEach ->
    spyOn(fs, 'createWriteStream')
    spyOn(NylasAPI, 'makeRequest')

  describe "constructor", ->
    it "should require a non-empty filename", ->
      expect(-> new Download(fileId: '123', targetPath: 'test.png')).toThrow()
      expect(-> new Download(filename: null, fileId: '123', targetPath: 'test.png')).toThrow()
      expect(-> new Download(filename: '', fileId: '123', targetPath: 'test.png')).toThrow()

    it "should require a non-empty fileId", ->
      expect(-> new Download(filename: 'test.png', fileId: null, targetPath: 'test.png')).toThrow()
      expect(-> new Download(filename: 'test.png', fileId: '', targetPath: 'test.png')).toThrow()

    it "should require a download path", ->
      expect(-> new Download(filename: 'test.png', fileId: '123')).toThrow()
      expect(-> new Download(filename: 'test.png', fileId: '123', targetPath: '')).toThrow()

  describe "run", ->
    beforeEach ->
      @download = new Download(fileId: '123', targetPath: 'test.png', filename: 'test.png')
      @download.run()
      expect(NylasAPI.makeRequest).toHaveBeenCalled()

    it "should create a request with a null encoding to prevent the request library from attempting to parse the (potentially very large) response", ->
      expect(NylasAPI.makeRequest.mostRecentCall.args[0].json).toBe(false)
      expect(NylasAPI.makeRequest.mostRecentCall.args[0].encoding).toBe(null)

    it "should create a request for /files/123/download", ->
      expect(NylasAPI.makeRequest.mostRecentCall.args[0].path).toBe("/files/123/download")

describe "FileDownloadStore", ->
  beforeEach ->
    spyOn(shell, 'showItemInFolder')
    spyOn(shell, 'openItem')
    @testfile = new File(filename: '123.png', contentType: 'image/png', id: 'id', size: 100)
    FileDownloadStore._downloads = {}
    FileDownloadStore._downloadDirectory = "/Users/testuser/.nylas/downloads"

  describe "pathForFile", ->
    it "should return path within the download directory with the file id and displayName", ->
      f = new File(filename: '123.png', contentType: 'image/png', id: 'id')
      spyOn(f, 'displayName').andCallThrough()
      expect(FileDownloadStore.pathForFile(f)).toBe("/Users/testuser/.nylas/downloads/id/123.png")
      expect(f.displayName).toHaveBeenCalled()

    it "should return unique paths for identical filenames with different IDs", ->
      f1 = new File(filename: '123.png', contentType: 'image/png', id: 'id1')
      f2 = new File(filename: '123.png', contentType: 'image/png', id: 'id2')
      expect(FileDownloadStore.pathForFile(f1)).toBe("/Users/testuser/.nylas/downloads/id1/123.png")
      expect(FileDownloadStore.pathForFile(f2)).toBe("/Users/testuser/.nylas/downloads/id2/123.png")

  describe "_checkForDownloadedFile", ->
    it "should return true if the file exists at the path and is the right size", ->
      f = new File(filename: '123.png', contentType: 'image/png', id: 'id', size: 100)
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback(null, {size: 100})
      waitsForPromise ->
        FileDownloadStore._checkForDownloadedFile(f).then (downloaded) ->
          expect(downloaded).toBe(true)

    it "should return false if the file does not exist", ->
      f = new File(filename: '123.png', contentType: 'image/png', id: 'id', size: 100)
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback(new Error("File does not exist"))
      waitsForPromise ->
        FileDownloadStore._checkForDownloadedFile(f).then (downloaded) ->
          expect(downloaded).toBe(false)

    it "should return false if the file is too small", ->
      f = new File(filename: '123.png', contentType: 'image/png', id: 'id', size: 100)
      spyOn(fs, 'stat').andCallFake (path, callback) ->
        callback(null, {size: 50})
      waitsForPromise ->
        FileDownloadStore._checkForDownloadedFile(f).then (downloaded) ->
          expect(downloaded).toBe(false)

  describe "_startDownload", ->
    beforeEach ->
      spyOn(FileDownloadStore.Download.prototype, 'run').andCallFake -> Promise.resolve()
      spyOn(FileDownloadStore, '_prepareFolder').andCallFake -> Promise.resolve(true)
      spyOn(FileDownloadStore, '_cleanupDownload')

    it "should make sure that the download file path exists", ->
      FileDownloadStore._startDownload(@testfile)
      expect(FileDownloadStore._prepareFolder).toHaveBeenCalled()

    it "should return the promise returned by download.run if the download already exists", ->
      existing =
        fileId: @testfile.id
        run: jasmine.createSpy('existing.run').andCallFake ->
          Promise.resolve(true)
      FileDownloadStore._downloads[@testfile.id] = existing

      promise = FileDownloadStore._startDownload(@testfile)
      expect(promise instanceof Promise).toBe(true)
      waitsForPromise ->
        promise.then ->
          expect(existing.run).toHaveBeenCalled()

    describe "when the downloaded file exists", ->
      beforeEach ->
        spyOn(FileDownloadStore, '_checkForDownloadedFile').andCallFake ->
          Promise.resolve(true)

      it "should resolve with a Download without calling download.run", ->
        waitsForPromise =>
          FileDownloadStore._startDownload(@testfile).then (download) ->
            expect(FileDownloadStore.Download.prototype.run).not.toHaveBeenCalled()
            expect(download instanceof FileDownloadStore.Download).toBe(true)
            expect(download.data()).toEqual({
              state : 'finished',
              fileId : 'id',
              percent : 0,
              filename : '123.png',
              filesize : 100,
              targetPath : '/Users/testuser/.nylas/downloads/id/123.png'
            })

    describe "when the downloaded file does not exist", ->
      beforeEach ->
        spyOn(FileDownloadStore, '_checkForDownloadedFile').andCallFake ->
          Promise.resolve(false)

      it "should register the download with the right attributes", ->
        FileDownloadStore._startDownload(@testfile)
        advanceClock(0)
        expect(FileDownloadStore.downloadDataForFile(@testfile.id)).toEqual({
          state : 'unstarted',fileId : 'id',
          percent : 0,
          filename : '123.png',
          filesize : 100,
          targetPath : '/Users/testuser/.nylas/downloads/id/123.png'
        })

      it "should call download.run", ->
        waitsForPromise =>
          FileDownloadStore._startDownload(@testfile)
        runs ->
          expect(FileDownloadStore.Download.prototype.run).toHaveBeenCalled()

      it "should resolve with a Download", ->
        waitsForPromise =>
          FileDownloadStore._startDownload(@testfile).then (download) ->
            expect(download instanceof FileDownloadStore.Download).toBe(true)
            expect(download.data()).toEqual({
              state : 'unstarted',
              fileId : 'id',
              percent : 0,
              filename : '123.png',
              filesize : 100,
              targetPath : '/Users/testuser/.nylas/downloads/id/123.png'
            })

  describe "_fetch", ->
    it "should call through to startDownload", ->
      spyOn(FileDownloadStore, '_startDownload')
      FileDownloadStore._fetch(@testfile)
      expect(FileDownloadStore._startDownload).toHaveBeenCalled()

  describe "_fetchAndOpen", ->
    it "should open the file once it's been downloaded", ->
      @savePath = "/Users/imaginary/.nylas/Downloads/a.png"
      download = {targetPath: @savePath}
      downloadResolve = null

      spyOn(FileDownloadStore, '_startDownload').andCallFake =>
        new Promise (resolve, reject) ->
          downloadResolve = resolve

      FileDownloadStore._fetchAndOpen(@testfile)
      expect(shell.openItem).not.toHaveBeenCalled()
      downloadResolve(download)
      advanceClock(100)
      expect(shell.openItem).toHaveBeenCalledWith(@savePath)

  describe "_fetchAndSave", ->
    beforeEach ->
      @savePath = "/Users/imaginary/.nylas/Downloads/b.png"
      spyOn(atom, 'showSaveDialog').andCallFake (options, callback) => callback(@savePath)

    it "should open a save dialog and prompt the user to choose a download path", ->
      spyOn(FileDownloadStore, '_startDownload').andCallFake =>
        new Promise (resolve, reject) -> # never resolve
      FileDownloadStore._fetchAndSave(@testfile)
      expect(atom.showSaveDialog).toHaveBeenCalled()
      expect(FileDownloadStore._startDownload).toHaveBeenCalledWith(@testfile)

    it "should copy the file to the download path after it's been downloaded and open it after the stream has ended", ->
      download = {targetPath: @savePath}
      onEndEventCallback = null
      streamStub =
        pipe: ->
        on: (eventName, eventCallback) =>
          onEndEventCallback = eventCallback

      spyOn(FileDownloadStore, '_startDownload').andCallFake =>
        Promise.resolve(download)
      spyOn(fs, 'createReadStream').andReturn(streamStub)
      spyOn(fs, 'createWriteStream')

      FileDownloadStore._fetchAndSave(@testfile)
      advanceClock(1)
      expect(fs.createReadStream).toHaveBeenCalledWith(download.targetPath)
      expect(shell.showItemInFolder).not.toHaveBeenCalled()
      onEndEventCallback()
      advanceClock(1)
      expect(shell.showItemInFolder).toHaveBeenCalledWith(download.targetPath)

  describe "_abortFetchFile", ->
    beforeEach ->
      @download =
        abort: jasmine.createSpy('abort')
        fileId: @testfile.id
      FileDownloadStore._downloads[@testfile.id] = @download

    it "should cancel the download for the provided file", ->
      spyOn(fs, 'exists').andCallFake (path, callback) -> callback(true)
      spyOn(fs, 'unlink')
      FileDownloadStore._abortFetchFile(@testfile)
      expect(fs.unlink).toHaveBeenCalled()
      expect(@download.abort).toHaveBeenCalled()

    it "should not try to delete the file if doesn't exist", ->
      spyOn(fs, 'exists').andCallFake (path, callback) -> callback(false)
      spyOn(fs, 'unlink')
      FileDownloadStore._abortFetchFile(@testfile)
      expect(fs.unlink).not.toHaveBeenCalled()
      expect(@download.abort).toHaveBeenCalled()
