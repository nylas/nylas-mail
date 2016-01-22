{$, $$}  = require '../src/space-pen-extensions'
Exec = require('child_process').exec
path = require 'path'
Package = require '../src/package'
ThemeManager = require '../src/theme-manager'

describe "the `NylasEnv` global", ->
  describe 'window sizing methods', ->
    describe '::getPosition and ::setPosition', ->
      it 'sets the position of the window, and can retrieve the position just set', ->
        NylasEnv.setPosition(22, 45)
        expect(NylasEnv.getPosition()).toEqual x: 22, y: 45

    describe '::getSize and ::setSize', ->
      originalSize = null
      beforeEach ->
        originalSize = NylasEnv.getSize()
      afterEach ->
        NylasEnv.setSize(originalSize.width, originalSize.height)

      it 'sets the size of the window, and can retrieve the size just set', ->
        NylasEnv.setSize(100, 400)
        expect(NylasEnv.getSize()).toEqual width: 100, height: 400

    describe '::setMinimumWidth', ->
      win = NylasEnv.getCurrentWindow()

      it "sets the minimum width", ->
        inputMinWidth = 500
        win.setMinimumSize(1000, 1000)

        NylasEnv.setMinimumWidth(inputMinWidth)

        [actualMinWidth, h] = win.getMinimumSize()
        expect(actualMinWidth).toBe inputMinWidth

      it "sets the current size if minWidth > current width", ->
        inputMinWidth = 1000
        win.setSize(500, 500)

        NylasEnv.setMinimumWidth(inputMinWidth)

        [actualWidth, h] = win.getMinimumSize()
        expect(actualWidth).toBe inputMinWidth

    describe '::getDefaultWindowDimensions', ->
      screen = require('remote').require 'screen'

      it "returns primary display's work area size if it's small enough", ->
        spyOn(screen, 'getPrimaryDisplay').andReturn workAreaSize: width: 1440, height: 900

        out = NylasEnv.getDefaultWindowDimensions()
        expect(out).toEqual x: 0, y: 0, width: 1440, height: 900

      it "caps width at 1440 and centers it, if wider", ->
        spyOn(screen, 'getPrimaryDisplay').andReturn workAreaSize: width: 1840, height: 900

        out = NylasEnv.getDefaultWindowDimensions()
        expect(out).toEqual x: 200, y: 0, width: 1440, height: 900

      it "caps height at 900 and centers it, if taller", ->
        spyOn(screen, 'getPrimaryDisplay').andReturn workAreaSize: width: 1440, height: 1100

        out = NylasEnv.getDefaultWindowDimensions()
        expect(out).toEqual x: 0, y: 100, width: 1440, height: 900

      it "returns only the max viewport size if it's smaller than the defaults", ->
        spyOn(screen, 'getPrimaryDisplay').andReturn workAreaSize: width: 1000, height: 800

        out = NylasEnv.getDefaultWindowDimensions()
        expect(out).toEqual x: 0, y: 0, width: 1000, height: 800

      it "always rounds X and Y", ->
        spyOn(screen, 'getPrimaryDisplay').andReturn workAreaSize: width: 1845, height: 955

        out = NylasEnv.getDefaultWindowDimensions()
        expect(out).toEqual x: 202, y: 27, width: 1440, height: 900


  describe ".isReleasedVersion()", ->
    it "returns false if the version is a SHA and true otherwise", ->
      version = '0.1.0'
      spyOn(NylasEnv, 'getVersion').andCallFake -> version
      expect(NylasEnv.isReleasedVersion()).toBe true
      version = '36b5518'
      expect(NylasEnv.isReleasedVersion()).toBe false

  xdescribe "when an update becomes available", ->
    subscription = null

    afterEach ->
      subscription?.dispose()

    it "invokes onUpdateAvailable listeners", ->
      updateAvailableHandler = jasmine.createSpy("update-available-handler")
      subscription = NylasEnv.onUpdateAvailable updateAvailableHandler

      autoUpdater = require('remote').require('auto-updater')
      autoUpdater.emit 'update-downloaded', null, "notes", "version"

      waitsFor ->
        updateAvailableHandler.callCount > 0

      runs ->
        {releaseVersion, releaseNotes} = updateAvailableHandler.mostRecentCall.args[0]
        expect(releaseVersion).toBe 'version'
        expect(releaseNotes).toBe 'notes'

  xdescribe "loading default config", ->
    it 'loads the default core config', ->
      expect(NylasEnv.config.get('core.excludeVcsIgnoredPaths')).toBe true
      expect(NylasEnv.config.get('core.followSymlinks')).toBe false
      expect(NylasEnv.config.get('editor.showInvisibles')).toBe false

  xdescribe "window onerror handler", ->
    beforeEach ->
      spyOn NylasEnv, 'openDevTools'
      spyOn NylasEnv, 'executeJavaScriptInDevTools'

    it "will open the dev tools when an error is triggered", ->
      try
        a + 1
      catch e
        window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

      expect(NylasEnv.openDevTools).toHaveBeenCalled()
      expect(NylasEnv.executeJavaScriptInDevTools).toHaveBeenCalled()

    describe "::onWillThrowError", ->
      willThrowSpy = null
      beforeEach ->
        willThrowSpy = jasmine.createSpy()

      it "is called when there is an error", ->
        error = null
        NylasEnv.onWillThrowError(willThrowSpy)
        try
          a + 1
        catch e
          error = e
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

        delete willThrowSpy.mostRecentCall.args[0].preventDefault
        expect(willThrowSpy).toHaveBeenCalledWith
          message: error.toString()
          url: 'abc'
          line: 2
          column: 3
          originalError: error

      it "will not show the devtools when preventDefault() is called", ->
        willThrowSpy.andCallFake (errorObject) -> errorObject.preventDefault()
        NylasEnv.onWillThrowError(willThrowSpy)

        try
          a + 1
        catch e
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e)

        expect(willThrowSpy).toHaveBeenCalled()
        expect(NylasEnv.openDevTools).not.toHaveBeenCalled()
        expect(NylasEnv.executeJavaScriptInDevTools).not.toHaveBeenCalled()

    describe "::onDidThrowError", ->
      didThrowSpy = null
      beforeEach ->
        didThrowSpy = jasmine.createSpy()

      it "is called when there is an error", ->
        error = null
        NylasEnv.onDidThrowError(didThrowSpy)
        try
          a + 1
        catch e
          error = e
          window.onerror.call(window, e.toString(), 'abc', 2, 3, e)
        expect(didThrowSpy).toHaveBeenCalledWith
          message: error.toString()
          url: 'abc'
          line: 2
          column: 3
          originalError: error
