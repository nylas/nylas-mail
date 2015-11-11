{$} = require '../src/space-pen-extensions'
path = require 'path'
Package = require '../src/package'
ThemePackage = require '../src/theme-package'

resolveFixturePath = (packagename) ->
  path.join(__dirname, 'fixtures', 'packages', packagename)

describe "Package", ->
  describe "when the package contains incompatible native modules", ->
    beforeEach ->
      spyOn(NylasEnv, 'inDevMode').andReturn(false)

    it "does not activate it", ->
      packagePath = resolveFixturePath('package-with-incompatible-native-module')
      pack = new Package(packagePath)
      expect(pack.isCompatible()).toBe false
      expect(pack.incompatibleModules[0].name).toBe 'native-module'
      expect(pack.incompatibleModules[0].path).toBe path.join(packagePath, 'node_modules', 'native-module')

    it "caches the incompatible native modules in local storage", ->
      packagePath = resolveFixturePath('package-with-incompatible-native-module')
      cacheKey = null
      cacheItem = null

      spyOn(global.localStorage, 'setItem').andCallFake (key, item) ->
        cacheKey = key
        cacheItem = item
      spyOn(global.localStorage, 'getItem').andCallFake (key) ->
        return cacheItem if cacheKey is key

      expect(new Package(packagePath).isCompatible()).toBe false
      expect(global.localStorage.getItem.callCount).toBe 1
      expect(global.localStorage.setItem.callCount).toBe 1

      expect(new Package(packagePath).isCompatible()).toBe false
      expect(global.localStorage.getItem.callCount).toBe 2
      expect(global.localStorage.setItem.callCount).toBe 1

  describe "theme", ->
    theme = null

    beforeEach ->
      $("#jasmine-content").append $("<nylas-theme-wrap></nylas-theme-wrap>")

    afterEach ->
      theme.deactivate() if theme?

    describe "when the theme contains a single style file", ->
      it "loads and applies css", ->
        expect($("nylas-theme-wrap").css("padding-bottom")).not.toBe "1234px"
        themePath = resolveFixturePath('theme-with-index-css')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("nylas-theme-wrap").css("padding-top")).toBe "1234px"

      it "parses, loads and applies less", ->
        expect($("nylas-theme-wrap").css("padding-bottom")).not.toBe "1234px"
        themePath = resolveFixturePath('theme-with-index-less')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("nylas-theme-wrap").css("padding-top")).toBe "4321px"

    describe "when the theme contains a package.json file", ->
      it "loads and applies stylesheets from package.json in the correct order", ->
        expect($("nylas-theme-wrap").css("padding-top")).not.toBe("101px")
        expect($("nylas-theme-wrap").css("padding-right")).not.toBe("102px")
        expect($("nylas-theme-wrap").css("padding-bottom")).not.toBe("103px")

        themePath = resolveFixturePath('theme-with-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("nylas-theme-wrap").css("padding-top")).toBe("101px")
        expect($("nylas-theme-wrap").css("padding-right")).toBe("102px")
        expect($("nylas-theme-wrap").css("padding-bottom")).toBe("103px")

    describe "when the theme does not contain a package.json file and is a directory", ->
      it "loads all stylesheet files in the directory", ->
        expect($("nylas-theme-wrap").css("padding-top")).not.toBe "10px"
        expect($("nylas-theme-wrap").css("padding-right")).not.toBe "20px"
        expect($("nylas-theme-wrap").css("padding-bottom")).not.toBe "30px"

        themePath = resolveFixturePath('theme-without-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()
        expect($("nylas-theme-wrap").css("padding-top")).toBe "10px"
        expect($("nylas-theme-wrap").css("padding-right")).toBe "20px"
        expect($("nylas-theme-wrap").css("padding-bottom")).toBe "30px"

    describe "reloading a theme", ->
      beforeEach ->
        themePath = resolveFixturePath('theme-with-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()

      it "reloads without readding to the stylesheets list", ->
        expect(theme.getStylesheetPaths().length).toBe 3
        theme.reloadStylesheets()
        expect(theme.getStylesheetPaths().length).toBe 3

    describe "events", ->
      beforeEach ->
        themePath = resolveFixturePath('theme-with-package-file')
        theme = new ThemePackage(themePath)
        theme.activate()

      it "deactivated event fires on .deactivate()", ->
        theme.onDidDeactivate spy = jasmine.createSpy()
        theme.deactivate()
        expect(spy).toHaveBeenCalled()
