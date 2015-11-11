path = require 'path'

_ = require 'underscore'
EmitterMixin = require('emissary').Emitter
{Emitter} = require 'event-kit'
fs = require 'fs-plus'
Q = require 'q'
Grim = require 'grim'

ServiceHub = require 'service-hub'
Package = require './package'
ThemePackage = require './theme-package'
DatabaseStore = require './flux/stores/database-store'
APMWrapper = require './apm-wrapper'

# Extended: Package manager for coordinating the lifecycle of N1 packages.
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
# Section: N1
module.exports =
class PackageManager
  EmitterMixin.includeInto(this)

  constructor: ({configDirPath, @devMode, safeMode, @resourcePath, @specMode}) ->
    @emitter = new Emitter
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
    @packagesWithDatabaseObjects = []
    @activePackages = {}
    @packageStates = {}
    @serviceHub = new ServiceHub

    @packageActivators = []
    @registerPackageActivator(this, ['nylas'])

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
    @emitter.on 'did-load-all', callback # TODO: Remove once deprecated pre-1.0 APIs are gone

  onDidLoadAll: (callback) ->
    Grim.deprecate("Use `::onDidLoadInitialPackages` instead.")
    @onDidLoadInitialPackages(callback)

  # Public: Invoke the given callback when all packages have been activated.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidActivateInitialPackages: (callback) ->
    @emitter.on 'did-activate-initial-packages', callback
    @emitter.on 'did-activate-all', callback # TODO: Remove once deprecated pre-1.0 APIs are gone

  onDidActivateAll: (callback) ->
    Grim.deprecate("Use `::onDidActivateInitialPackages` instead.")
    @onDidActivateInitialPackages(callback)

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

  on: (eventName) ->
    switch eventName
      when 'loaded'
        Grim.deprecate 'Use PackageManager::onDidLoadInitialPackages instead'
      when 'activated'
        Grim.deprecate 'Use PackageManager::onDidActivateInitialPackages instead'
      else
        Grim.deprecate 'PackageManager::on is deprecated. Use event subscription methods instead.'
    EmitterMixin::on.apply(this, arguments)

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

    @apmPath = path.join(process.resourcesPath, 'app', 'apm', 'bin', commandName)
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
    return name if fs.isDirectorySync(name)

    packagePath = fs.resolve(@packageDirPaths..., name)
    return packagePath if fs.isDirectorySync(packagePath)

    packagePath = path.join(@resourcePath, 'node_modules', name)
    return packagePath if @nasNylasEngine(packagePath)

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

    for packageDirPath in @packageDirPaths
      for packagePath in fs.listSync(packageDirPath)
        # Ignore files in package directory
        continue unless fs.isDirectorySync(packagePath)
        # Ignore .git in package directory
        continue if path.basename(packagePath)[0] is '.'
        packagePaths.push(packagePath)

    if windowType
      packagePaths = _.filter packagePaths, (packagePath) ->
        try
          {windowTypes} = Package.loadMetadata(packagePath) ? {}
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
    dialog = require('remote').require('dialog')
    shell = require('shell')

    packagesDir = path.join(NylasEnv.getConfigDirPath(), 'packages')
    packageName = path.basename(packageSourceDir)
    packageTargetDir = path.join(packagesDir, packageName)

    fs.makeTree packagesDir, (err) =>
      return callback(err, null) if err

      fs.exists packageTargetDir, (packageAlreadyExists) =>
        if packageAlreadyExists
          message = "A package named '#{packageName}' is already installed
                 in ~/.nylas/packages."
          dialog.showMessageBox({
            type: 'warning'
            buttons: ['OK']
            title: 'Package already installed'
            detail: 'Remove it before trying to install another package of the same name.'
            message: message
          })
          callback(new Error(message), null)
          return

        fs.copySync(packageSourceDir, packageTargetDir)

        apm = new APMWrapper()
        apm.installDependenciesInPackageDirectory packageTargetDir, (err) =>
          if err
            dialog.showMessageBox({
              type: 'warning'
              buttons: ['OK']
              title: 'Package installation failed'
              message: err.toString()
            })
            callback(err, packageTargetDir)
          else
            @enablePackage(packageTargetDir)
            @activatePackage(packageName)
            callback(null, packageTargetDir)

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

  nasNylasEngine: (packagePath) ->
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
        pack.load()
        if pack.declaresNewDatabaseObjects
          @packagesWithDatabaseObjects.push pack
        @loadedPackages[pack.name] = pack
        @emitter.emit 'did-load-package', pack
        return pack
      catch error
        console.warn "Failed to load package.json '#{path.basename(packagePath)}'"
        console.warn error.stack ? error
    else
      console.warn "Could not resolve '#{nameOrPath}' to a package path"
    null

  unloadPackages: ->
    @unloadPackage(name) for name in _.keys(@loadedPackages)
    null

  unloadPackage: (name) ->
    if @isPackageActive(name)
      throw new Error("Tried to unload active package '#{name}'")

    if pack = @getLoadedPackage(name)
      delete @loadedPackages[pack.name]
      @emitter.emit 'did-unload-package', pack
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
        promises.push(promise) unless pack.hasActivationCommands()
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
