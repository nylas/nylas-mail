_ = require 'underscore'
Reflux = require 'reflux'
path = require 'path'
fs = require 'fs-plus'
PluginsActions = require './plugins-actions'
{APMWrapper} = require 'nylas-exports'

{ipcRenderer, shell, remote} = require 'electron'
dialog = remote.require('dialog')

module.exports =
PackagesStore = Reflux.createStore

  init: ->
    @_apm = new APMWrapper()

    @_globalSearch = ""
    @_installedSearch = ""
    @_installing = {}
    @_featured = {themes: [], packages: []}
    @_newerVersions = []
    @_searchResults = null
    @_refreshFeatured()

    @listenTo PluginsActions.refreshFeaturedPackages, @_refreshFeatured
    @listenTo PluginsActions.refreshInstalledPackages, @_refreshInstalled

    NylasEnv.commands.add 'body',
      'application:create-package': => @_onCreatePackage()

    NylasEnv.commands.add 'body',
      'application:install-package': => @_onInstallPackage()

    @listenTo PluginsActions.createPackage, @_onCreatePackage
    @listenTo PluginsActions.updatePackage, @_onUpdatePackage
    @listenTo PluginsActions.setGlobalSearchValue, @_onGlobalSearchChange
    @listenTo PluginsActions.setInstalledSearchValue, @_onInstalledSearchChange

    @listenTo PluginsActions.showPackage, (pkg) =>
      dir = NylasEnv.packages.resolvePackagePath(pkg.name)
      shell.showItemInFolder(dir) if dir

    @listenTo PluginsActions.installPackage, (pkg) =>
      @_installing[pkg.name] = true
      @trigger(@)
      @_apm.install pkg, (err) =>
        if err
          delete @_installing[pkg.name]
          @_displayMessage("Sorry, an error occurred", err.toString())
        else
          if NylasEnv.packages.isPackageDisabled(pkg.name)
            NylasEnv.packages.enablePackage(pkg.name)
        @_onPackagesChanged()

    @listenTo PluginsActions.uninstallPackage, (pkg) =>
      if NylasEnv.packages.isPackageLoaded(pkg.name)
        NylasEnv.packages.disablePackage(pkg.name)
        NylasEnv.packages.unloadPackage(pkg.name)
      @_apm.uninstall pkg, (err) =>
        @_displayMessage("Sorry, an error occurred", err.toString()) if err
        @_onPackagesChanged()

    @listenTo PluginsActions.enablePackage, (pkg) ->
      if NylasEnv.packages.isPackageDisabled(pkg.name)
        NylasEnv.packages.enablePackage(pkg.name)

    @listenTo PluginsActions.disablePackage, (pkg) ->
      unless NylasEnv.packages.isPackageDisabled(pkg.name)
        NylasEnv.packages.disablePackage(pkg.name)

    @_hasPrepared = false

  # Getters

  installed: ->
    @_prepareIfFresh()
    @_addPackageStates(@_filter(@_installed, @_installedSearch))

  installedSearchValue: ->
    @_installedSearch

  featured: ->
    @_prepareIfFresh()
    @_addPackageStates(@_featured)

  searchResults: ->
    @_addPackageStates(@_searchResults)

  globalSearchValue: ->
    @_globalSearch

  # Action Handlers

  _prepareIfFresh: ->
    return if @_hasPrepared
    NylasEnv.packages.onDidActivatePackage(=> @_onPackagesChangedDebounced())
    NylasEnv.packages.onDidDeactivatePackage(=> @_onPackagesChangedDebounced())
    NylasEnv.packages.onDidLoadPackage(=> @_onPackagesChangedDebounced())
    NylasEnv.packages.onDidUnloadPackage(=> @_onPackagesChangedDebounced())
    @_onPackagesChanged()
    @_hasPrepared = true

  _filter: (hash, search) ->
    result = {}
    search = search.toLowerCase()
    for key, pkgs of hash
      result[key] = _.filter pkgs, (p) =>
        search.length is 0 or p.name.toLowerCase().indexOf(search) isnt -1
    result

  _refreshFeatured: ->
    @_apm.getFeatured({themes: false}).then (results) =>
      @_featured.packages = results
      @trigger()
    .catch (err) =>
      # We may be offline
    @_apm.getFeatured({themes: true}).then (results) =>
      @_featured.themes = results
      @trigger()
    .catch (err) =>
      # We may be offline

  _refreshInstalled: ->
    @_onPackagesChanged()

  _refreshSearch: ->
    return unless @_globalSearch?.length > 0

    @_apm.search(@_globalSearch).then (results) =>
      @_searchResults =
        packages: results.filter ({theme}) -> not theme
        themes: results.filter ({theme}) -> theme
      @trigger()
    .catch (err) =>
      # We may be offline

  _refreshSearchThrottled: _.debounce((-> @_refreshSearch()), 400)

  _onPackagesChanged: ->
    @_apm.getInstalled().then (packages) =>
      for category in ['dev', 'user']
        packages[category] = packages[category].filter ({theme}) -> not theme
        packages[category].forEach (pkg) =>
          pkg.category = category
          delete @_installing[pkg.name]

      available = NylasEnv.packages.getAvailablePackageMetadata()
      examples = available.filter ({isOptional}) -> isOptional
      packages['example'] = examples.map (pkg) ->
        _.extend({}, pkg, {installed: true, category: 'example'})

      @_installed = packages
      @trigger()

    @_apm.getOutdated().then (packages) =>
      @_newerVersions = {}
      for pkg in packages
        @_newerVersions[pkg.name] = pkg.latestVersion
      @trigger()

  _onPackagesChangedDebounced: _.debounce((-> @_onPackagesChanged()), 200)

  _onInstalledSearchChange: (val) ->
    @_installedSearch = val
    @trigger()

  _onUpdatePackage: (pkg) ->
    @_apm.update(pkg, pkg.newerVersion)

  _onInstallPackage: ->
    NylasEnv.showOpenDialog
      title: "Choose a Package Directory"
      properties: ['openDirectory']
    , (filenames) =>
      return if not filenames or filenames.length is 0
      NylasEnv.packages.installPackageFromPath filenames[0], (err, packageTargetDir) =>
        return if err
        packageName = path.basename(filenames[0])
        msg = "#{packageName} has been installed and enabled. No need to \
               restart! If you don't see the package loaded, check the \
               console for errors."
        @_displayMessage("Package installed", msg)
        if packageTargetDir
          shell.showItemInFolder(packageTargetDir)

  _onCreatePackage: ->
    if not NylasEnv.inDevMode()
      btn = dialog.showMessageBox
        type: 'warning'
        message: "Run with debug flags?"
        detail: "To develop plugins, you should run N1 with debug flags.
                This gives you better error messages, the debug version of
                React, and more. You can disable it at any time from the
                Developer menu."
        buttons: ["OK", "Cancel"]
      if btn is 0
        ipcRenderer.send('command', 'application:toggle-dev')
      return

    packagesDir = path.join(NylasEnv.getConfigDirPath(), 'dev', 'packages')
    fs.makeTreeSync(packagesDir)

    NylasEnv.showSaveDialog
      title: "Save New Package"
      defaultPath: packagesDir
      properties: ['createDirectory']
    , (packageDir) =>
      return unless packageDir

      packageName = path.basename(packageDir)

      if not packageDir.startsWith(packagesDir)
        return @_displayMessage('Invalid package location', 'Sorry, you must
                                    create packages in the packages folder.')

      if NylasEnv.packages.resolvePackagePath(packageName)
        return @_displayMessage('Invalid package name', 'Sorry, you must
                                    give your package a unqiue name.')

      if packageName.indexOf(' ') isnt -1
        return @_displayMessage('Invalid package name', 'Sorry, package names
                                 cannot contain spaces.')

      fs.mkdir packageDir, (err) =>
        return @_displayMessage('Could not create package', err.toString()) if err

        {resourcePath} = NylasEnv.getLoadSettings()
        packageTemplatePath = path.join(resourcePath, 'static', 'package-template')
        packageJSON =
          name: packageName
          main: "./lib/main"
          version: '0.1.0'
          repository:
            type: 'git'
            url: ''
          engines:
            nylas: ">=#{NylasEnv.getVersion()}"
          description: "Enter a description of your package!"
          dependencies: {}
          license: "MIT"

        fs.copySync(packageTemplatePath, packageDir)
        fs.writeFileSync(path.join(packageDir, 'package.json'), JSON.stringify(packageJSON, null, 2))
        shell.showItemInFolder(packageDir)
        _.defer ->
          NylasEnv.packages.enablePackage(packageDir)
          NylasEnv.packages.activatePackage(packageName)

  _onGlobalSearchChange: (val) ->
    # Clear previous search results data if this is a new
    # search beginning from "".
    if @_globalSearch.length is 0 and val.length > 0
      @_searchResults = null

    @_globalSearch = val
    @_refreshSearchThrottled()
    @trigger()

  _addPackageStates: (pkgs) ->
    installedNames = _.flatten(_.values(@_installed)).map (pkg) -> pkg.name

    _.flatten(_.values(pkgs)).forEach (pkg) =>
      pkg.enabled = !NylasEnv.packages.isPackageDisabled(pkg.name)
      pkg.installed = pkg.name in installedNames
      pkg.installing = @_installing[pkg.name]?
      pkg.newerVersionAvailable = @_newerVersions[pkg.name]?
      pkg.newerVersion = @_newerVersions[pkg.name]

    pkgs

  _displayMessage: (title, message) ->
    dialog.showMessageBox
      type: 'warning'
      message: title
      detail: message
      buttons: ["OK"]
