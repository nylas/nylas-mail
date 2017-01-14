path = require 'path'

_ = require 'underscore'
async = require 'async'
fs = require 'fs-plus'
EmitterMixin = require('emissary').Emitter
{Emitter, CompositeDisposable} = require 'event-kit'
Q = require 'q'

ModuleCache = require './module-cache'

TaskRegistry = require('./registries/task-registry').default
DatabaseObjectRegistry = require('./registries/database-object-registry').default

try
  packagesCache = require('../package.json')?._N1Packages ? {}
catch error
  packagesCache = {}

# Loads and activates a package's main module and resources such as
# stylesheets, keymaps, and menus.
module.exports =
class Package
  EmitterMixin.includeInto(this)

  @isBundledPackagePath: (packagePath) ->
    if NylasEnv.packages.devMode
      return false unless NylasEnv.packages.resourcePath.startsWith("#{process.resourcesPath}#{path.sep}")

    @resourcePathWithTrailingSlash ?= "#{NylasEnv.packages.resourcePath}#{path.sep}"
    packagePath?.startsWith(@resourcePathWithTrailingSlash)

  @loadMetadata: (packagePath, ignoreErrors=false) ->
    packageName = path.basename(packagePath)
    if @isBundledPackagePath(packagePath)
      metadata = packagesCache[packageName]?.metadata
    unless metadata?
      metadataPath = fs.resolve(path.join(packagePath, 'package.json'))
      if fs.existsSync(metadataPath)
        try
          metadata = JSON.parse(fs.readFileSync(metadataPath))
        catch error
          throw error unless ignoreErrors
    metadata ?= {}
    metadata.name = packageName

    if metadata.stylesheets?
      metadata.styleSheets = metadata.stylesheets

    metadata

  keymaps: null
  menus: null
  stylesheets: null
  stylesheetDisposables: null
  mainModulePath: null
  resolvedMainModulePath: false
  mainModule: null

  ###
  Section: Construction
  ###

  constructor: (@path, @metadata) ->
    @emitter = new Emitter
    @metadata ?= Package.loadMetadata(@path)
    @bundledPackage = Package.isBundledPackagePath(@path)
    @name = @metadata?.name ? path.basename(@path)
    @pluginAppId = @name

    @displayName = @metadata?.displayName || @name
    ModuleCache.add(@path, @metadata)
    @reset()
    @declaresNewDatabaseObjects = false

  # TODO FIXME: Use a unique pluginID instead of just the "name"
  # This needs to be included here to prevent a circular dependency error
  pluginId: -> return @pluginAppId ? @name

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDeactivate: (callback) ->
    @emitter.on 'did-deactivate', callback

  ###
  Section: Instance Methods
  ###

  enable: ->
    NylasEnv.config.removeAtKeyPath('core.disabledPackages', @name)

  disable: ->
    NylasEnv.config.pushAtKeyPath('core.disabledPackages', @name)

  isTheme: ->
    @metadata?.theme?

  measure: (key, fn) ->
    startTime = Date.now()
    value = fn()
    @[key] = Date.now() - startTime
    value

  getType: -> 'nylas'

  getStyleSheetPriority: -> 0

  load: ->
    @measure 'loadTime', =>
      try
        @declaresNewDatabaseObjects = false
        @loadKeymaps()
        @loadMenus()
        @loadStylesheets()
        mainModule = @requireMainModule()
        return unless mainModule
        @registerModelConstructors(mainModule.modelConstructors)
        @registerTaskConstructors(mainModule.taskConstructors)

      catch error
        console.warn "Failed to load package named '#{@name}'"
        console.warn error.stack ? error
        console.error(error.message, error)
    this

  registerModelConstructors: (constructors=[]) ->
    if constructors.length > 0
      @declaresNewDatabaseObjects = true

      _.each constructors, (constructor) ->
        constructorFactory = -> constructor
        DatabaseObjectRegistry.register(constructor.name, constructorFactory)

  registerTaskConstructors: (constructors=[]) ->
    _.each constructors, (constructor) ->
      constructorFactory = -> constructor
      TaskRegistry.register(constructor.name, constructorFactory)

  reset: ->
    @stylesheets = []
    @keymaps = []
    @menus = []

  activate: ->
    unless @activationDeferred?
      @activationDeferred = Q.defer()
      @measure 'activateTime', =>
        @activateResources()
        @activateNow()

    Q.all([@activationDeferred.promise])

  activateNow: ->
    try
      @activateConfig()
      @activateStylesheets()
      if @requireMainModule()
        localState = NylasEnv.packages.getPackageState(@name) ? {}
        @mainModule.activate(localState)
        @mainActivated = true
    catch e
      console.error e.message
      console.error e.stack
      console.warn "Failed to activate package named '#{@name}'", e.stack

    @activationDeferred?.resolve()

  activateConfig: ->
    return if @configActivated

    @requireMainModule()
    if @mainModule?
      if @mainModule.config? and typeof @mainModule.config is 'object'
        NylasEnv.config.setSchema @name, {type: 'object', properties: @mainModule.config}
      else if @mainModule.configDefaults? and typeof @mainModule.configDefaults is 'object'
        NylasEnv.config.setDefaults(@name, @mainModule.configDefaults)
      @mainModule.activateConfig?()
    @configActivated = true

  activateStylesheets: ->
    return if @stylesheetsActivated

    @stylesheetDisposables = new CompositeDisposable

    priority = @getStyleSheetPriority()
    for [sourcePath, source] in @stylesheets
      if match = path.basename(sourcePath).match(/[^.]*\.([^.]*)\./)
        context = match[1]
      else
        context = undefined

      @stylesheetDisposables.add(NylasEnv.styles.addStyleSheet(source, {sourcePath, priority, context}))
    @stylesheetsActivated = true

  activateResources: ->
    @activationDisposables = new CompositeDisposable
    @activationDisposables.add(NylasEnv.keymaps.loadKeymap(keymapPath, map)) for [keymapPath, map] in @keymaps
    @activationDisposables.add(NylasEnv.menu.add(map['menu'])) for [menuPath, map] in @menus when map['menu']?

  loadKeymaps: ->
    try
      if @bundledPackage and packagesCache[@name]?
        @keymaps = (["#{NylasEnv.packages.resourcePath}#{path.sep}#{keymapPath}", keymapObject] for keymapPath, keymapObject of packagesCache[@name].keymaps)
      else
        @keymaps = @getKeymapPaths().map (keymapPath) -> [keymapPath, JSON.parse(fs.readFileSync(keymapPath)) ? {}]
    catch e
      console.error "Error reading keymaps for package '#{@name}': #{e.message}", e.stack

  loadMenus: ->
    try
      if @bundledPackage and packagesCache[@name]?
        @menus = (["#{NylasEnv.packages.resourcePath}#{path.sep}#{menuPath}", menuObject] for menuPath, menuObject of packagesCache[@name].menus)
      else
        @menus = @getMenuPaths().map (menuPath) -> [menuPath, JSON.parse(fs.readFileSync(menuPath)) ? {}]
    catch e
      console.error "Error reading menus for package '#{@name}': #{e.message}", e.stack

    for [menuPath, menuObj] in @menus
      menuItem.isOptional = @metadata.isOptional for menuItem in menuObj.menu

  getKeymapPaths: ->
    keymapsDirPath = path.join(@path, 'keymaps')
    if @metadata.keymaps
      @metadata.keymaps.map (name) -> fs.resolve(keymapsDirPath, name, ['json', ''])
    else
      fs.listSync(keymapsDirPath, ['json'])

  getMenuPaths: ->
    menusDirPath = path.join(@path, 'menus')
    if @metadata.menus
      @metadata.menus.map (name) -> fs.resolve(menusDirPath, name, ['json', ''])
    else
      fs.listSync(menusDirPath, ['json'])

  loadStylesheets: ->
    @stylesheets = @getStylesheetPaths().map (stylesheetPath) ->
      [stylesheetPath, NylasEnv.themes.loadStylesheet(stylesheetPath, true)]

  getStylesheetsPath: ->
    if fs.isDirectorySync(path.join(@path, 'stylesheets'))
      path.join(@path, 'stylesheets')
    else
      path.join(@path, 'styles')

  getStylesheetPaths: ->
    stylesheetDirPath = @getStylesheetsPath()
    if @metadata.mainStyleSheet
      [fs.resolve(@path, @metadata.mainStyleSheet)]
    else if @metadata.styleSheets
      @metadata.styleSheets.map (name) -> fs.resolve(stylesheetDirPath, name, ['css', 'less', ''])
    else if indexStylesheet = fs.resolve(@path, 'index', ['css', 'less'])
      [indexStylesheet]
    else
      _.filter fs.listSync(stylesheetDirPath, ['css', 'less']), (file) ->
        path.basename(file)[0] isnt '.'

  serialize: ->
    if @mainActivated
      try
        @mainModule?.serialize?()
      catch e
        console.error "Error serializing package '#{@name}'", e.stack

  deactivate: ->
    @activationDeferred?.reject()
    @activationDeferred = null
    @deactivateResources()
    @deactivateConfig()
    if @mainActivated
      try
        @mainModule?.deactivate?()
      catch e
        console.error "Error deactivating package '#{@name}'", e.stack
    @emit 'deactivated'
    @emitter.emit 'did-deactivate'

  deactivateConfig: ->
    @mainModule?.deactivateConfig?()
    @configActivated = false

  deactivateResources: ->
    @stylesheetDisposables?.dispose()
    @activationDisposables?.dispose()
    @stylesheetsActivated = false

  reloadStylesheets: ->
    oldSheets = _.clone(@stylesheets)
    @loadStylesheets()
    @stylesheetDisposables?.dispose()
    @stylesheetDisposables = new CompositeDisposable
    @stylesheetsActivated = false
    @activateStylesheets()

  requireMainModule: ->
    return @mainModule if @mainModule?
    unless @isCompatible()
      console.warn """
        Failed to require the main module of '#{@name}' because it requires an incompatible native module.
        Run `apm rebuild` in the package directory to resolve.
      """
      return
    mainModulePath = @getMainModulePath()
    if fs.isFileSync(mainModulePath)
      @mainModule = require(mainModulePath)
    return @mainModule

  getMainModulePath: ->
    return @mainModulePath if @resolvedMainModulePath
    @resolvedMainModulePath = true

    if @bundledPackage and packagesCache[@name]?
      if packagesCache[@name].main
        @mainModulePath = "#{NylasEnv.packages.resourcePath}#{path.sep}#{packagesCache[@name].main}"
        @mainModulePath = fs.resolveExtension(@mainModulePath, ["", Object.keys(require.extensions)...])
      else
        @mainModulePath = null
    else
      mainModulePath =
        if @metadata.main
          path.join(@path, @metadata.main)
        else
          path.join(@path, 'index')
      @mainModulePath = fs.resolveExtension(mainModulePath, ["", Object.keys(require.extensions)...])

  isNativeModule: (modulePath) ->
    try
      fs.listSync(path.join(modulePath, 'build', 'Release'), ['.node']).length > 0
    catch error
      false

  # Get an array of all the native modules that this package depends on.
  # This will recurse through all dependencies.
  getNativeModuleDependencyPaths: ->
    nativeModulePaths = []

    traversePath = (nodeModulesPath) =>
      try
        for modulePath in fs.listSync(nodeModulesPath)
          nativeModulePaths.push(modulePath) if @isNativeModule(modulePath)
          traversePath(path.join(modulePath, 'node_modules'))

    traversePath(path.join(@path, 'node_modules'))
    nativeModulePaths

  # Get the incompatible native modules that this package depends on.
  # This recurses through all dependencies and requires all modules that
  # contain a `.node` file.
  #
  # This information is cached in local storage on a per package/version basis
  # to minimize the impact on startup time.
  getIncompatibleNativeModules: ->
    localStorageKey = "installed-packages:#{@name}:#{@metadata.version}"
    unless NylasEnv.inDevMode()
      try
        {incompatibleNativeModules} = JSON.parse(global.localStorage.getItem(localStorageKey)) ? {}
      return incompatibleNativeModules if incompatibleNativeModules?

    incompatibleNativeModules = []
    for nativeModulePath in @getNativeModuleDependencyPaths()
      try
        require(nativeModulePath)
      catch error
        try
          version = require("#{nativeModulePath}/package.json").version
        incompatibleNativeModules.push
          path: nativeModulePath
          name: path.basename(nativeModulePath)
          version: version
          error: error.message

    global.localStorage.setItem(localStorageKey, JSON.stringify({incompatibleNativeModules}))
    incompatibleNativeModules

  # Public: Is this package compatible with this version of N1?
  #
  # Incompatible packages cannot be activated. This will include packages
  # installed to ~/.nylas-mail/packages that were built against node 0.11.10 but
  # now need to be upgrade to node 0.11.13.
  #
  # Returns a {Boolean}, true if compatible, false if incompatible.
  isCompatible: ->
    return @compatible if @compatible?

    if @path.indexOf(path.join(NylasEnv.packages.resourcePath, 'node_modules') + path.sep) is 0
      # Bundled packages are always considered compatible
      @compatible = true
    else if packageMain = @getMainModulePath()
      @incompatibleModules = @getIncompatibleNativeModules()
      @compatible = @incompatibleModules.length is 0
    else
      @compatible = true
