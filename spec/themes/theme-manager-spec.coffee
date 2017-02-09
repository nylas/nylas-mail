path = require 'path'

fs = require 'fs-plus'
temp = require 'temp'

ThemeManager = require '../../src/theme-manager'
Package = require '../../src/package'

describe "ThemeManager", ->
  themeManager = null
  resourcePath = NylasEnv.getLoadSettings().resourcePath
  configDirPath = NylasEnv.getConfigDirPath()

  beforeEach ->
    # spyOn(console, "log")
    spyOn(console, "warn")
    spyOn(console, "error")
    theme_dir = path.resolve(__dirname, '../../internal_packages')

    # Don't load ALL of our packages. Some packages may do very expensive
    # and asynchronous things on require, including hitting the database.
    packagePaths = [
      path.resolve(__dirname, '../../internal_packages/ui-light')
      path.resolve(__dirname, '../../internal_packages/ui-dark')
    ]
    spyOn(NylasEnv.packages, "getAvailablePackagePaths").andReturn packagePaths
    NylasEnv.packages.packageDirPaths.unshift(theme_dir)
    themeManager = new ThemeManager({packageManager: NylasEnv.packages, resourcePath, configDirPath})

  afterEach ->
    themeManager.deactivateThemes()

  describe "theme getters and setters", ->
    beforeEach ->
      NylasEnv.packages.loadPackages()

    it 'getLoadedThemes get all the loaded themes', ->
      themes = themeManager.getLoadedThemes()
      expect(themes.length).toEqual(2)

    it 'getActiveThemes get all the active themes', ->
      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        names = NylasEnv.config.get('core.themes')
        expect(names.length).toBeGreaterThan(0)
        themes = themeManager.getActiveThemes()
        expect(themes).toHaveLength(names.length)

  describe "when the core.themes config value contains invalid entry", ->
    it "ignores theme", ->
      NylasEnv.config.set 'core.themes', [
        'ui-light'
        null
        undefined
        ''
        false
        4
        {}
        []
        'ui-dark'
      ]

      expect(themeManager.getEnabledThemeNames()).toEqual ['ui-dark', 'ui-light']

  describe "::getImportPaths()", ->
    it "returns the theme directories before the themes are loaded", ->
      NylasEnv.config.set('core.themes', ['theme-with-index-less', 'ui-dark', 'ui-light'])

      paths = themeManager.getImportPaths()

      # syntax theme is not a dir at this time, so only two.
      expect(paths.length).toBe 2
      expect(paths[0]).toContain 'ui-light'
      expect(paths[1]).toContain 'ui-dark'

    it "ignores themes that cannot be resolved to a directory", ->
      NylasEnv.config.set('core.themes', ['definitely-not-a-theme'])
      expect(-> themeManager.getImportPaths()).not.toThrow()

  describe "when the core.themes config value changes", ->
    it "add/removes stylesheets to reflect the new config value", ->
      themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        didChangeActiveThemesHandler.reset()
        NylasEnv.config.set('core.themes', [])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        expect(document.querySelectorAll('style.theme')).toHaveLength 0
        NylasEnv.config.set('core.themes', ['ui-dark'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        sheets = Array.from(document.querySelectorAll('style[priority="1"]'))
        expect(sheets).toHaveLength 1
        expect(sheets[0].getAttribute('source-path')).toMatch /ui-dark/
        NylasEnv.config.set('core.themes', ['ui-light', 'ui-dark'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        sheets = Array.from(document.querySelectorAll('style[priority="1"]'))
        expect(sheets).toHaveLength 2
        expect(sheets[0].getAttribute('source-path')).toMatch /ui-dark/
        expect(sheets[1].getAttribute('source-path')).toMatch /ui-light/
        NylasEnv.config.set('core.themes', [])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        didChangeActiveThemesHandler.reset()
        sheets = Array.from(document.querySelectorAll('style[priority="1"]'))
        expect(sheets).toHaveLength(1)
        # ui-dark has an directory path, the syntax one doesn't
        NylasEnv.config.set('core.themes', ['theme-with-index-less', 'ui-light'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount == 1

      runs ->
        sheets = Array.from(document.querySelectorAll('style[priority="1"]'))
        expect(sheets).toHaveLength 2
        importPaths = themeManager.getImportPaths()
        expect(importPaths.length).toBe 1
        expect(importPaths[0]).toContain 'ui-light'

    it 'adds theme-* classes to the workspace for each active theme', ->
      themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        expect(document.body.classList.contains('theme-ui-light')).toBe(true)
        themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
        NylasEnv.config.set('core.themes', ['theme-with-ui-variables'])

      waitsFor ->
        didChangeActiveThemesHandler.callCount > 0

      runs ->
        # `theme-` twice as it prefixes the name with `theme-`
        expect(document.body.classList.contains('theme-theme-with-ui-variables')).toBe(true)
        expect(document.body.classList.contains('theme-ui-dark')).toBe(false)

  describe "when a theme fails to load", ->
    it "logs a warning", ->
      NylasEnv.packages.activatePackage('a-theme-that-will-not-be-found')
      .then () ->
        expect("This should have thrown!!").toBe(true)
      .catch (err) ->
        expect(err.message).toMatch(/Failed to load/)
        expect(console.warn.callCount).toBe 1
        expect(console.warn.argsForCall[0][0]).toContain "Could not resolve 'a-theme-that-will-not-be-found'"

  describe "::requireStylesheet(path)", ->
    afterEach ->
      themeManager.removeStylesheet(path.join(__dirname, '..', 'fixtures', 'css.css'))
      themeManager.removeStylesheet(path.join(__dirname, '..', 'fixtures', 'sample.less'))

    it "synchronously loads css at the given path and installs a style tag for it in the head", ->
      NylasEnv.styles.onDidAddStyleElement styleElementAddedHandler = jasmine.createSpy("styleElementAddedHandler")

      cssPath = path.join(__dirname, '..', 'fixtures', 'css.css')
      lengthBefore = document.querySelectorAll('head style').length

      themeManager.requireStylesheet(cssPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1

      expect(styleElementAddedHandler).toHaveBeenCalled()

      element = document.querySelector('head style[source-path*="css.css"]')
      expect(element.getAttribute('source-path')).toBe themeManager.stringToId(cssPath)
      expect(element.textContent).toBe fs.readFileSync(cssPath, 'utf8')

      # doesn't append twice
      styleElementAddedHandler.reset()
      themeManager.requireStylesheet(cssPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1
      expect(styleElementAddedHandler).not.toHaveBeenCalled()

      element.remove()

    it "synchronously loads and parses less files at the given path and installs a style tag for it in the head", ->
      lessPath = path.join(__dirname, '..', 'fixtures', 'sample.less')
      lengthBefore = document.querySelectorAll('head style').length
      themeManager.requireStylesheet(lessPath)
      lengthAfter = document.querySelectorAll('head style').length
      expect(lengthAfter).toBe lengthBefore + 1

      element = document.querySelector('head style[source-path*="sample.less"]')
      expect(element.getAttribute('source-path')).toBe themeManager.stringToId(lessPath)
      expect(element.textContent).toBe """
      #header {
        color: #4d926f;
      }
      h2 {
        color: #4d926f;
      }

      """

      # doesn't append twice
      themeManager.requireStylesheet(lessPath)
      expect(document.querySelectorAll('head style').length).toBe lengthBefore + 1
      element.remove()

    it "supports requiring css and less stylesheets without an explicit extension", ->
      themeManager.requireStylesheet path.join(__dirname, '..', 'fixtures', 'css')
      expect(document.querySelector('head style[source-path*="css.css"]').getAttribute('source-path')).toBe themeManager.stringToId(path.join(__dirname, '..', 'fixtures', 'css.css'))
      themeManager.requireStylesheet path.join(__dirname, '..', 'fixtures', 'sample')
      expect(document.querySelector('head style[source-path*="sample.less"]').getAttribute('source-path')).toBe themeManager.stringToId(path.join(__dirname, '..', 'fixtures', 'sample.less'))

      document.querySelector('head style[source-path*="css.css"]').remove()
      document.querySelector('head style[source-path*="sample.less"]').remove()

    it "returns a disposable allowing styles applied by the given path to be removed", ->
      cssPath = require.resolve('../fixtures/css.css')

      expect(window.getComputedStyle(document.body)['font-weight']).not.toBe("bold")
      disposable = themeManager.requireStylesheet(cssPath)
      expect(window.getComputedStyle(document.body)['font-weight']).toBe("bold")

      NylasEnv.styles.onDidRemoveStyleElement styleElementRemovedHandler = jasmine.createSpy("styleElementRemovedHandler")
      disposable.dispose()

      expect(window.getComputedStyle(document.body)['font-weight']).not.toBe("bold")
      expect(styleElementRemovedHandler).toHaveBeenCalled()

  describe "base style sheet loading", ->
    workspaceElement = null
    beforeEach ->
      workspaceElement = document.createElement('nylas-workspace')
      workspaceElement.appendChild document.createElement('nylas-theme-wrap')
      jasmine.attachToDOM(workspaceElement)

      waitsForPromise ->
        themeManager.activateThemes()

      runs ->
        themeManager.onDidChangeActiveThemes didChangeActiveThemesHandler = jasmine.createSpy()
        additionalDelay = null
        @waitsForThemeRefresh = ->
          waitsFor ->
            # We need to wait a bit of additional time for the browser to actually
            # apply the CSS to the elements we check.
            if didChangeActiveThemesHandler.callCount > 0
              additionalDelay ?= Date.now() + 100
              return Date.now() > additionalDelay
            return false

    it "loads the correct values from the theme's ui-variables file", ->
      NylasEnv.config.set('core.themes', ['theme-with-ui-variables'])

      @waitsForThemeRefresh()
      runs ->
        # an override loaded in the base css of theme-with-ui-variables
        expect(getComputedStyle(workspaceElement)["background-color"]).toBe "rgb(0, 0, 255)"

        # a value that is not overridden in the theme
        node = document.querySelector('nylas-theme-wrap')
        nodeStyle = window.getComputedStyle(node)
        expect(nodeStyle['padding-top']).toBe "150px"
        expect(nodeStyle['padding-right']).toBe "150px"
        expect(nodeStyle['padding-bottom']).toBe "150px"

    describe "when there is a theme with incomplete variables", ->
      it "loads the correct values from the fallback ui-variables", ->
        NylasEnv.config.set('core.themes', ['theme-with-incomplete-ui-variables'])

        @waitsForThemeRefresh()
        runs ->
          # an override loaded in the base css of theme-with-incomplete-ui-variables
          expect(getComputedStyle(workspaceElement)["background-color"]).toBe "rgb(0, 0, 255)"

            # a value that is not overridden in the theme
          node = document.querySelector('nylas-theme-wrap')
          nodeStyle = window.getComputedStyle(node)
          expect(nodeStyle['background-color']).toBe "rgb(152, 123, 0)"

  describe "when a non-existent theme is present in the config", ->
    beforeEach ->
      NylasEnv.config.set('core.themes', ['non-existent-dark-ui'])

      waitsForPromise ->
        themeManager.activateThemes()

    it 'uses the default theme and logs a warning', ->
      activeThemeNames = themeManager.getActiveThemeNames()
      expect(console.warn.callCount).toBe(1)
      expect(activeThemeNames.length).toBe(1)
      expect(activeThemeNames).toContain('ui-light')

  describe "when in safe mode", ->
    beforeEach ->
      themeManager = new ThemeManager({packageManager: NylasEnv.packages, resourcePath, configDirPath, safeMode: true})

    describe 'when the enabled UI theme is bundled with N1', ->
      beforeEach ->
        NylasEnv.config.set('core.themes', ['ui-light'])

        waitsForPromise ->
          themeManager.activateThemes()

      it 'uses the enabled themes', ->
        activeThemeNames = themeManager.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(1)
        expect(activeThemeNames).toContain('ui-light')

    describe 'when the enabled UI theme is not bundled with N1', ->
      beforeEach ->
        NylasEnv.config.set('core.themes', ['installed-dark-ui'])

        waitsForPromise ->
          themeManager.activateThemes()

      it 'uses the default UI theme', ->
        activeThemeNames = themeManager.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(1)
        expect(activeThemeNames).toContain('ui-light')

    describe 'when the enabled UI theme is not bundled with N1', ->
      beforeEach ->
        NylasEnv.config.set('core.themes', ['installed-dark-ui'])

        waitsForPromise ->
          themeManager.activateThemes()

      it 'uses the default UI theme', ->
        activeThemeNames = themeManager.getActiveThemeNames()
        expect(activeThemeNames.length).toBe(1)
        expect(activeThemeNames).toContain('ui-light')
