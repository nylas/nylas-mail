path = require 'path'
url = require 'url'

_ = require 'underscore'
{ipcRenderer, remote} = require 'electron'
EmitterMixin = require('emissary').Emitter
{Emitter} = require 'event-kit'
fs = require 'fs-plus'
Q = require 'q'

Actions = require('./flux/actions').default
Package = require './package'
ThemePackage = require './theme-package'
DatabaseStore = require('./flux/stores/database-store').default
APMWrapper = require './apm-wrapper'

basePackagePaths = null

# Extended: Package manager for coordinating the lifecycle of Nylas Mail packages.
#
# An instance of this class is always available as the `NylasEnv.packages` global.
#
# Packages can be loaded, activated, and deactivated, and unloaded:
#  * Loading a package reads and parses the package's metadata and resources
#    such as keymaps, menus, stylesheets, etc.
#  * Activating a package registers the loaded resources and calls `activate()`
#    on the package's main module.
#  * Deactivating a package unregisters the package's resources  and calls
#    `deactivate()` on the package's main module.
#  * Unloading a package removes it completely from the package manager.
#
# Packages can be enabled/disabled via the `core.disabledPackages` config
# settings and also by calling `enablePackage()/disablePackage()`.
#
# Section: NylasEnv
module.exports =
class PackageManager
  EmitterMixin.includeInto(this)

  constructor: ({configDirPath, @devMode, safeMode, @resourcePath, @specMode}) ->
    @emitter = new Emitter
    @onPluginsChanged = _.debounce(@_onPluginsChanged, 200)
    @packageDirPaths = []
    if @specMode
      @packageDirPaths.push(path.join(@resourcePath, "spec", "fixtures", "packages"))
    else
      @packageDirPaths.push(path.join(@resourcePath, "internal_packages"))
      if not safeMode
        if @devMode
          @packageDirPaths.push(path.join(configDirPath, "dev", "packages"))
        @packageDirPaths.push(path.join(configDirPath, "packages"))

    @loadedPackages = {}
    @cachedPackagePluginIds = {}
    @packagesWithDatabaseObjects = []
    @activePackages = {}
    @packageStates = {}

    @packageActivators = []
    @registerPackageActivator(this, ['nylas'])

    ipcRenderer.on("changePluginStateFromUrl", @_onChangePluginState)


  pluginIdFor: (packageName) =>
    env = NylasEnv.config.get("env")
    cacheKey = "#{packageName}:#{env}"

    if @cachedPackagePluginIds[cacheKey] is undefined
      @cachedPackagePluginIds[cacheKey] = @_resolvePluginIdFor(packageName, env)
    return @cachedPackagePluginIds[cacheKey]

  _onChangePluginState: (event, urlToOpen = "") =>
    {query} = url.parse(urlToOpen, true)
    disabled = NylasEnv.config.get('core.disabledPackages') ? []
    turnedOn = []
    turnedOff = []
    for name, state of query
      continue if /-displayName/gi.test(name)
      displayName = query["#{name}-displayName"] ? name
      if state is "off" and name not in disabled
        turnedOff.push(displayName)
        if name not in disabled then disabled.push(name)
      else if state is "on"
        turnedOn.push(displayName)
        disabled = _.without(disabled, name)
    NylasEnv.config.set('core.disabledPackages', disabled)
    if NylasEnv.isMainWindow() then NylasEnv.focus()
    if turnedOn.length > 0 then @_notifyPluginsChanged(turnedOn, "enabled")
    if turnedOff.length > 0 then @_notifyPluginsChanged(turnedOff, "disabled")

  _notifyPluginsChanged: (names, dir) =>
    if names.length >= 2
      last = names[names.length - 1]
      names[names.length - 1] = "and #{last}"
    has = if names.length is 1 then "has" else "have"
    pluginText = if names.length is 1 then "Plugin" else "Plugins"
    setTimeout =>
      remote.dialog.showMessageBox(remote.getCurrentWindow(), {
        type: 'info',
        message: "#{pluginText} #{dir}",
        detail: "#{names.join(", ")} #{has} been #{dir}"
        buttons: ['Thanks'],
      })
    , 500

  _resolvePluginIdFor: (packageName, env) =>
    metadata = @loadedPackages[packageName]?.metadata

    unless metadata
      packagePath = @resolvePackagePath(packageName)
      return null unless packagePath
      metadata = Package.loadMetadata(packagePath)

    return metadata.name if metadata
    return null

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when all packages have been loaded.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidLoadInitialPackages: (callback) ->
    @emitter.on 'did-load-initial-packages', callback

  # Public: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivateInitialPackages: (callback) ->
    @emitter.on 'did-activate-initial-packages', callback

  # Public: Invoke the given callback when a package is activated.
  #
  # * `callback` A {Function} to be invoked when a package is activated.
  #   * `package` The {Package} that was activated.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivatePackage: (callback) ->
    @emitter.on 'did-activate-package', callback

  # Public: Invoke the given callback when a package is deactivated.
  #
  # * `callback` A {Function} to be invoked when a package is deactivated.
  #   * `package` The {Package} that was deactivated.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDeactivatePackage: (callback) ->
    @emitter.on 'did-deactivate-package', callback

  # Public: Invoke the given callback when a package is loaded.
  #
  # * `callback` A {Function} to be invoked when a package is loaded.
  #   * `package` The {Package} that was loaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidLoadPackage: (callback) ->
    @emitter.on 'did-load-package', callback

  # Public: Invoke the given callback when a package is unloaded.
  #
  # * `callback` A {Function} to be invoked when a package is unloaded.
  #   * `package` The {Package} that was unloaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidUnloadPackage: (callback) ->
    @emitter.on 'did-unload-package', callback

  ###
  Section: Package system data
  ###

  # Public: Get the path to the apm command.
  #
  # Return a {String} file path to apm.
  getApmPath: ->
    return @apmPath if @apmPath?

    commandName = 'apm'
    commandName += '.cmd' if process.platform is 'win32'

    @apmPath = path.join(process.resourcesPath, 'apm', 'bin', commandName)
    if not fs.isFileSync(@apmPath)
      @apmPath = path.join(@resourcePath, 'apm', 'bin', commandName)
    if not fs.isFileSync(@apmPath)
      @apmPath = path.join(@resourcePath, 'apm', 'node_modules', 'atom-package-manager', 'bin', commandName)
    @apmPath

  # Public: Get the paths being used to look for packages.
  #
  # Returns an {Array} of {String} directory paths.
  getPackageDirPaths: ->
    _.clone(@packageDirPaths)

  ###
  Section: General package data
  ###

  # Public: Resolve the given package name to a path on disk.
  #
  # * `name` - The {String} package name.
  #
  # Return a {String} folder path or undefined if it could not be resolved.
  resolvePackagePath: (name) ->
    packagePath = fs.resolve(@packageDirPaths..., name)
    return packagePath if fs.isDirectorySync(packagePath)

    packagePath = path.join(@resourcePath, 'node_modules', name)
    return packagePath if @hasNylasEngine(packagePath)

  # Public: Is the package with the given name bundled with Nylas?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isBundledPackage: (name) ->
    @getPackageDependencies().hasOwnProperty(name)

  ###
  Section: Enabling and disabling packages
  ###

  # Public: Enable the package with the given name.
  #
  # Returns the {Package} that was enabled or null if it isn't loaded.
  enablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.enable()
    pack

  # Public: Disable the package with the given name.
  #
  # Returns the {Package} that was disabled or null if it isn't loaded.
  disablePackage: (name) ->
    pack = @loadPackage(name)
    pack?.disable()
    pack

  # Public: Is the package with the given name disabled?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isPackageDisabled: (name) ->
    _.include(NylasEnv.config.get('core.disabledPackages') ? [], name)

  ###
  Section: Accessing active packages
  ###

  # Public: Get an {Array} of all the active {Package}s.
  getActivePackages: ->
    _.values(@activePackages)

  # Public: Get the active {Package} with the given name.
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Package} or undefined.
  getActivePackage: (name) ->
    @activePackages[name]

  # Public: Is the {Package} with the given name active?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isPackageActive: (name) ->
    @getActivePackage(name)?

  ###
  Section: Accessing loaded packages
  ###

  # Public: Get an {Array} of all the loaded {Package}s
  getLoadedPackages: ->
    _.values(@loadedPackages)

  # Get packages for a certain package type
  #
  # * `types` an {Array} of {String}s like ['nylas', 'my-package'].
  getLoadedPackagesForTypes: (types) ->
    pack for pack in @getLoadedPackages() when pack.getType() in types

  # Public: Get the loaded {Package} with the given name.
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Package} or undefined.
  getLoadedPackage: (name) ->
    @loadedPackages[name]

  # Public: Gets the root paths of all loaded packages.
  #
  # Useful when determining if an error originated from a package.
  getPluginIdsByPathBase: ->
    pluginIdsByPathBase = {}
    for name, pack of @loadedPackages
      pathBase = _.last(pack.path.split("/"))

      if pack.pluginId() and pack.pluginId() isnt name
        id = "#{name}-#{pack.pluginId()}"
      else
        id = pack.pluginId()

      pluginIdsByPathBase[pathBase] = id
    return pluginIdsByPathBase

  # Public: Is the package with the given name loaded?
  #
  # * `name` - The {String} package name.
  #
  # Returns a {Boolean}.
  isPackageLoaded: (name) ->
    @getLoadedPackage(name)?

  ###
  Section: Accessing available packages
  ###

  # Public: Get an {Array} of {String}s of all the available package paths.
  #
  # If the optional windowType is passed, it will only load packages
  # that declare that windowType in their package.json
  getAvailablePackagePaths: (windowType) ->
    packagePaths = []

    loadPackagesWhenNoTypesSpecified = windowType is 'default'

    basePackagePaths ?= NylasEnv.fileListCache().basePackagePaths ? []
    if basePackagePaths.length is 0
      for packageDirPath in @packageDirPaths
        for packagePath in fs.listSync(packageDirPath)
          # Ignore files in package directory
          continue unless fs.isDirectorySync(packagePath)
          # Ignore .git in package directory
          continue if path.basename(packagePath)[0] is '.'
          packagePaths.push(packagePath)
      basePackagePaths = packagePaths
      cache = NylasEnv.fileListCache()
      cache.basePackagePaths = basePackagePaths
    else
      packagePaths = basePackagePaths

    if windowType
      packagePaths = _.filter packagePaths, (packagePath) ->
        try
          metadata = Package.loadMetadata(packagePath) ? {}

          if not (metadata.engines?.nylas)
            console.error("INVALID PACKAGE: Your package at #{packagePath} does not have a properly formatted `package.json`. You must include an {'engines': {'nylas': version}} property")

          {windowTypes} = metadata
          if windowTypes
            return windowTypes[windowType]? or windowTypes["all"]?
          else if loadPackagesWhenNoTypesSpecified
            return true
          return false
        catch
          return false

    packagesPath = path.join(@resourcePath, 'node_modules')
    for packageName, packageVersion of @getPackageDependencies()
      packagePath = path.join(packagesPath, packageName)
      packagePaths.push(packagePath) if fs.isDirectorySync(packagePath)

    _.uniq(packagePaths)

  # Public: Get an {Array} of {String}s of all the available package names.
  getAvailablePackageNames: ->
    _.uniq _.map @getAvailablePackagePaths(), (packagePath) -> path.basename(packagePath)

  # Public: Get an {Array} of {String}s of all the available package metadata.
  getAvailablePackageMetadata: ->
    packages = []
    for packagePath in @getAvailablePackagePaths()
      name = path.basename(packagePath)
      metadata = @getLoadedPackage(name)?.metadata ? Package.loadMetadata(packagePath, true)
      packages.push(metadata)
    packages

  installPackageFromPath: (packageSourceDir, callback) ->
    jsonPath = path.join(packageSourceDir, 'package.json')
    if not fs.existsSync(jsonPath)
      return callback(new Error("The folder you selected doesn't look like a valid N1 plugin. All N1 plugins must have a package.json file in the top level of the folder. Check the contents of #{packageSourceDir} and try again."), null)

    try
      json = JSON.parse(fs.readFileSync(jsonPath))
    catch e
      return callback(e, null)

    if not json.name
      return callback(new Error("The package.json file must contain a valid `name` value."), null)

    packagesDir = path.join(NylasEnv.getConfigDirPath(), 'packages')
    packageName = json.name
    packageTargetDir = path.join(packagesDir, packageName)

    fs.makeTree packagesDir, (err) =>
      return callback(err, null) if err

      fs.exists packageTargetDir, (packageAlreadyExists) =>
        if packageAlreadyExists
          return callback(new Error("A package named '#{packageName}' is already installed in ~/.nylas-mail/packages."), null)

        fs.copySync(packageSourceDir, packageTargetDir)

        apm = new APMWrapper()
        apm.installDependenciesInPackageDirectory packageTargetDir, (err) =>
          return callback(err, packageTargetDir) if err
          @enablePackage(packageTargetDir)
          @activatePackage(packageName)
          callback(null, packageName)

  ###
  Section: Private
  ###

  getPackageState: (name) ->
    @packageStates[name]

  setPackageState: (name, state) ->
    @packageStates[name] = state

  getPackageDependencies: ->
    unless @packageDependencies?
      try
        metadataPath = path.join(@resourcePath, 'package.json')
        {@packageDependencies} = JSON.parse(fs.readFileSync(metadataPath)) ? {}
      @packageDependencies ?= {}

    @packageDependencies

  hasNylasEngine: (packagePath) ->
    metadata = Package.loadMetadata(packagePath, true)
    metadata?.engines?.nylas?

  unobserveDisabledPackages: ->
    @disabledPackagesSubscription?.dispose()
    @disabledPackagesSubscription = null

  observeDisabledPackages: ->
    @disabledPackagesSubscription ?= NylasEnv.config.onDidChange 'core.disabledPackages', ({newValue, oldValue}) =>
      packagesToEnable = _.difference(oldValue, newValue)
      packagesToDisable = _.difference(newValue, oldValue)

      @deactivatePackage(packageName) for packageName in packagesToDisable when @getActivePackage(packageName)

      for packageName in packagesToEnable
        @loadPackage(packageName)

      @refreshDatabaseSchema()

      for packageName in packagesToEnable
        @activatePackage(packageName)

      null

  # This lets us report the active plugins in the main window (since plugins
  # are window-specific). Useful for letting the worker window know what
  # plugins are installed in the main window.
  _onPluginsChanged: =>
    return unless NylasEnv.isMainWindow()
    # All active plugins, core optional, core required, and 3rd party
    activePluginNames = @getActivePackages().map((p) -> p.name)

    # Only active 3rd party plugins
    activeThirdPartyPluginNames = @getActivePackages().filter((p) ->
      (p.path?.indexOf('internal_packages') is -1 and
      p.path?.indexOf('nylas-private') is -1)
    ).map((p) -> p.name)

    # Only active core optional, and core required plugins
    activeCorePluginNames = _.difference(activePluginNames, activeThirdPartyPluginNames)

    # All plugins (3rd party and core optional) that have the {optional: true}
    # flag.  If it's an internal_packages core package, it'll show up in
    # preferences.
    optionalPluginNames = @getAvailablePackageMetadata()
      .filter(({isOptional}) -> isOptional)
      .map((p) -> p.name)

    activeCoreOptionalPluginNames = _.intersection(activeCorePluginNames, optionalPluginNames)

    Actions.notifyPluginsChanged({
      allActivePluginNames: activePluginNames
      coreActivePluginNames: activeCoreOptionalPluginNames
      thirdPartyActivePluginNames: activeThirdPartyPluginNames
    })

  # If a windowType is passed, we'll only load packages who declare that
  # windowType as `true` in their package.json file.
  loadPackages: (windowType) ->
    packagePaths = @getAvailablePackagePaths(windowType)

    packagePaths = packagePaths.filter (packagePath) => not @isPackageDisabled(path.basename(packagePath))
    packagePaths = _.uniq packagePaths, (packagePath) -> path.basename(packagePath)
    @loadPackage(packagePath) for packagePath in packagePaths
    @emit 'loaded'
    @emitter.emit 'did-load-initial-packages'

  loadPackage: (nameOrPath) ->
    return pack if pack = @getLoadedPackage(nameOrPath)

    if packagePath = @resolvePackagePath(nameOrPath)
      name = path.basename(nameOrPath)
      return pack if pack = @getLoadedPackage(name)

      try
        metadata = Package.loadMetadata(packagePath) ? {}
        if metadata.theme
          pack = new ThemePackage(packagePath, metadata)
        else
          pack = new Package(packagePath, metadata)

        if metadata.supportedEnvs && !metadata.supportedEnvs.includes(NylasEnv.config.get('env'))
          return null

        pack.load()
        if pack.declaresNewDatabaseObjects
          @packagesWithDatabaseObjects.push pack
        @loadedPackages[pack.name] = pack
        @emitter.emit 'did-load-package', pack
        @onPluginsChanged()
        return pack
      catch error
        console.warn "Failed to load package.json '#{path.basename(packagePath)}'"
        console.warn error.stack ? error
    else
      console.warn "Could not resolve '#{nameOrPath}' to a package path"
    null

  unloadPackages: ->
    @unloadPackage(name) for name in Object.keys(@loadedPackages)
    null

  unloadPackage: (name) ->
    if @isPackageActive(name)
      throw new Error("Tried to unload active package '#{name}'")

    if pack = @getLoadedPackage(name)
      delete @loadedPackages[pack.name]
      @emitter.emit 'did-unload-package', pack
      @onPluginsChanged()
    else
      throw new Error("No loaded package for name '#{name}'")

  # Activate all the packages that should be activated.
  activate: ->
    promises = []
    for [activator, types] in @packageActivators
      packages = @getLoadedPackagesForTypes(types)
      promises = promises.concat(activator.activatePackages(packages))
    Q.all(promises).then =>
      @emit 'activated'
      @emitter.emit 'did-activate-initial-packages'

  # another type of package manager can handle other package types.
  # See ThemeManager
  registerPackageActivator: (activator, types) ->
    @packageActivators.push([activator, types])

  activatePackages: (packages) ->
    promises = []
    NylasEnv.config.transact =>
      for pack in packages
        @loadPackage(pack.name)

      @refreshDatabaseSchema()

      for pack in packages
        promise = @activatePackage(pack.name)
        promises.push(promise)
    @observeDisabledPackages()
    promises

  # When packages load they can declare new DatabaseObjects that need to
  # be setup in the Database. It's important that the Database starts
  # getting setup before packages activate so any DB queries in the
  # `activate` methods get properly queued then executed.
  #
  # When a package with database-altering changes loads, it will put an
  # entry in `packagesWithDatabaseObjects`.
  refreshDatabaseSchema: ->
    if @packagesWithDatabaseObjects.length > 0
      DatabaseStore.refreshDatabaseSchema()
      @packagesWithDatabaseObjects = []

  # Activate a single package by name
  activatePackage: (name) ->
    if pack = @getActivePackage(name)
      Q(pack)
    else if pack = @loadPackage(name)
      pack.activate().then =>
        @activePackages[pack.name] = pack
        @emitter.emit 'did-activate-package', pack
        @onPluginsChanged()
        pack
    else
      Q.reject(new Error("Failed to load package '#{name}'"))

  # Deactivate all packages
  deactivatePackages: ->
    NylasEnv.config.transact =>
      @deactivatePackage(pack.name) for pack in @getLoadedPackages()
    @unobserveDisabledPackages()

  # Deactivate the package with the given name
  deactivatePackage: (name) ->
    pack = @getLoadedPackage(name)
    if @isPackageActive(name)
      @setPackageState(pack.name, state) if state = pack.serialize?()
    pack.deactivate()
    delete @activePackages[pack.name]
    @emitter.emit 'did-deactivate-package', pack
    @onPluginsChanged()
