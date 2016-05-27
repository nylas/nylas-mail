path = require 'path'

_ = require 'underscore'
EmitterMixin = require('emissary').Emitter
{Emitter, Disposable, CompositeDisposable} = require 'event-kit'
{File} = require 'pathwatcher'
fs = require 'fs-plus'
Q = require 'q'

Package = require './package'

# Extended: Handles loading and activating available themes.
#
# An instance of this class is always available as the `NylasEnv.themes` global.
module.exports =
class ThemeManager
  EmitterMixin.includeInto(this)

  constructor: ({@packageManager, @resourcePath, @configDirPath, @safeMode}) ->
    @emitter = new Emitter
    @styleSheetDisposablesBySourcePath = {}
    @lessCache = null
    @initialLoadComplete = false
    @packageManager.registerPackageActivator(this, ['theme'])
    @sheetsByStyleElement = new WeakMap

    stylesElement = document.head.querySelector('nylas-styles')
    stylesElement.onDidAddStyleElement @styleElementAdded.bind(this)
    stylesElement.onDidRemoveStyleElement @styleElementRemoved.bind(this)
    stylesElement.onDidUpdateStyleElement @styleElementUpdated.bind(this)

  baseThemeName: -> 'ui-light'

  watchCoreStyles: ->
    console.log('Watching /static and /internal_packages for LESS changes')
    watchStylesIn = (folder) =>
      stylePaths = fs.listTreeSync(folder)
      PathWatcher = require 'pathwatcher'
      for stylePath in stylePaths
        continue unless path.extname(stylePath) is '.less'
        PathWatcher.watch stylePath, =>
          @activateThemes()
    watchStylesIn("#{@resourcePath}/static")
    watchStylesIn("#{@resourcePath}/internal_packages")

  styleElementAdded: (styleElement) ->
    {sheet} = styleElement
    @sheetsByStyleElement.set(styleElement, sheet)
    @emitter.emit 'did-add-stylesheet', sheet
    @emitter.emit 'did-change-stylesheets'

  styleElementRemoved: (styleElement) ->
    sheet = @sheetsByStyleElement.get(styleElement)
    @emitter.emit 'did-remove-stylesheet', sheet
    @emitter.emit 'did-change-stylesheets'

  styleElementUpdated: ({sheet}) ->
    @emitter.emit 'did-remove-stylesheet', sheet
    @emitter.emit 'did-add-stylesheet', sheet
    @emitter.emit 'did-change-stylesheets'

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke `callback` when style sheet changes associated with
  # updating the list of active themes have completed.
  #
  # * `callback` {Function}
  onDidChangeActiveThemes: (callback) ->
    @emitter.on 'did-change-active-themes', callback

  ###
  Section: Accessing Available Themes
  ###

  getAvailableNames: ->
    # TODO: Maybe should change to list all the available themes out there?
    @getLoadedNames()

  ###
  Section: Accessing Loaded Themes
  ###

  # Public: Get an array of all the loaded theme names.
  getLoadedThemeNames: ->
    theme.name for theme in @getLoadedThemes()

  # Public: Get an array of all the loaded themes.
  getLoadedThemes: ->
    pack for pack in @packageManager.getLoadedPackages() when pack.isTheme()

  ###
  Section: Accessing Active Themes
  ###

  # Public: Get an array of all the active theme names.
  getActiveThemeNames: ->
    theme.name for theme in @getActiveThemes()

  # Public: Get an array of all the active themes.
  getActiveThemes: ->
    pack for pack in @packageManager.getActivePackages() when pack.isTheme()

  getActiveTheme: ->
    # The first element in the array returned by `getActiveNames` themes will
    # actually be the active theme
    @getActiveThemes()[0]

  activatePackages: -> @activateThemes()

  ###
  Section: Managing Enabled Themes
  ###

  # Public: Get the enabled theme names from the config.
  #
  # Returns an array of theme names in the order that they should be activated.
  getEnabledThemeNames: ->
    themeNames = NylasEnv.config.get('core.themes') ? []
    themeNames = [themeNames] unless _.isArray(themeNames)
    themeNames = themeNames.filter (themeName) ->
      if themeName and typeof themeName is 'string'
        return true if NylasEnv.packages.resolvePackagePath(themeName)
        console.warn("Enabled theme '#{themeName}' is not installed.")
      false

    # Use a built-in theme any time the configured themes are not
    # available.
    if themeNames.length is 0
      builtInThemeNames = [
        'ui-light', 'ui-dark'
      ]
      themeNames = _.intersection(themeNames, builtInThemeNames)
      if themeNames.length is 0
        themeNames = ['ui-light']

    # Reverse so the first (top) theme is loaded after the others. We want
    # the first/top theme to override later themes in the stack.
    themeNames.reverse()

  # Set the active theme.
  # Because of how theme-manager works, we always need to set the
  # base theme first, and the newly activated theme after it to override the
  # styles. We don't want to have more than 1 theme active at a time, so the
  # array of active themes should always be of size 2.
  #
  # * `theme` {string} - the theme to activate
  setActiveTheme: (theme) ->
    base = @baseThemeName()
    NylasEnv.config.set('core.themes', _.uniq [base, theme])

  ###
  Section: Private
  ###

  # Resolve and apply the stylesheet specified by the path.
  #
  # This supports both CSS and Less stylsheets.
  #
  # * `stylesheetPath` A {String} path to the stylesheet that can be an absolute
  #   path or a relative path that will be resolved against the load path.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # required stylesheet.
  requireStylesheet: (stylesheetPath) ->
    if fullPath = @resolveStylesheet(stylesheetPath)
      content = @loadStylesheet(fullPath)
      @applyStylesheet(fullPath, content)
    else
      throw new Error("Could not find a file at path '#{stylesheetPath}'")

  loadBaseStylesheets: ->
    @reloadBaseStylesheets()

  reloadBaseStylesheets: ->
    @requireStylesheet('../static/index')
    @requireStylesheet('../static/email-frame')
    if nativeStylesheetPath = fs.resolveOnLoadPath(process.platform, ['css', 'less'])
      @requireStylesheet(nativeStylesheetPath)

  stylesheetElementForId: (id) ->
    document.head.querySelector("nylas-styles style[source-path=\"#{id}\"]")

  resolveStylesheet: (stylesheetPath) ->
    if path.extname(stylesheetPath).length > 0
      fs.resolveOnLoadPath(stylesheetPath)
    else
      fs.resolveOnLoadPath(stylesheetPath, ['css', 'less'])

  loadStylesheet: (stylesheetPath, importFallbackVariables) ->
    if path.extname(stylesheetPath) is '.less'
      @loadLessStylesheet(stylesheetPath, importFallbackVariables)
    else
      fs.readFileSync(stylesheetPath, 'utf8')

  loadLessStylesheet: (lessStylesheetPath, importFallbackVariables=false) ->
    unless @lessCache?
      LessCompileCache = require './less-compile-cache'
      @lessCache = new LessCompileCache({@configDirPath, @resourcePath, importPaths: @getImportPaths()})

    try
      if importFallbackVariables
        baseVarImports = """
        @import "variables/ui-variables";
        """
        less = fs.readFileSync(lessStylesheetPath, 'utf8')
        @lessCache.cssForFile(lessStylesheetPath, [baseVarImports, less].join('\n'))
      else
        @lessCache.read(lessStylesheetPath)
    catch error
      if error.line?
        message = "Error compiling Less stylesheet: `#{lessStylesheetPath}`"
        detail = """
          Line number: #{error.line}
          #{error.message}
        """
      else
        message = "Error loading Less stylesheet: `#{lessStylesheetPath}`"
        detail = error.message

      console.error(message, {detail, dismissable: true})
      console.error(detail)
      throw error

  removeStylesheet: (stylesheetPath) ->
    @styleSheetDisposablesBySourcePath[stylesheetPath]?.dispose()

  applyStylesheet: (path, text) ->
    @styleSheetDisposablesBySourcePath[path] = NylasEnv.styles.addStyleSheet(text, sourcePath: path)

  stringToId: (string) ->
    string.replace(/\\/g, '/')

  activateThemes: ->
    deferred = Q.defer()

    # NylasEnv.config.observe runs the callback once, then on subsequent changes.
    NylasEnv.config.observe 'core.themes', =>
      @deactivateThemes()

      # Refreshing the less cache is very expensive (hundreds of ms). It
      # will be refreshed once the promise resolves after packages are
      # activated.

      promises = []
      for themeName in @getEnabledThemeNames()
        if @packageManager.resolvePackagePath(themeName)
          promises.push(@packageManager.activatePackage(themeName))
        else
          console.warn("Failed to activate theme '#{themeName}' because it isn't installed.")

      Q.all(promises).then =>
        @addActiveThemeClasses()
        @refreshLessCache() # Update cache again now that @getActiveThemes() is populated
        @reloadBaseStylesheets()
        @initialLoadComplete = true
        @emitter.emit 'did-change-active-themes'
        deferred.resolve()

    deferred.promise

  deactivateThemes: ->
    @removeActiveThemeClasses()
    @packageManager.deactivatePackage(pack.name) for pack in @getActiveThemes()
    null

  isInitialLoadComplete: -> @initialLoadComplete

  addActiveThemeClasses: ->
    for pack in @getActiveThemes()
      document.body.classList.add("theme-#{pack.name}")
    return

  removeActiveThemeClasses: ->
    for pack in @getActiveThemes()
      document.body.classList.remove("theme-#{pack.name}")
    return

  refreshLessCache: ->
    @lessCache?.setImportPaths(@getImportPaths())

  getImportPaths: ->
    activeThemes = @getActiveThemes()
    if activeThemes.length > 0
      themePaths = (theme.getStylesheetsPath() for theme in activeThemes when theme)
    else
      themePaths = []
      for themeName in @getEnabledThemeNames()
        if themePath = @packageManager.resolvePackagePath(themeName)
          deprecatedPath = path.join(themePath, 'stylesheets')
          if fs.isDirectorySync(deprecatedPath)
            themePaths.push(deprecatedPath)
          else
            themePaths.push(path.join(themePath, 'styles'))

    themePaths.filter (themePath) -> fs.isDirectorySync(themePath)
