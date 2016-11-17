import _ from 'underscore';
import Reflux from 'reflux';
import path from 'path';
import fs from 'fs-plus';
import {APMWrapper} from 'nylas-exports';
import {ipcRenderer, shell, remote} from 'electron';

import PluginsActions from './plugins-actions';

const dialog = remote.dialog;


const PackagesStore = Reflux.createStore({
  init: function init() {
    this._apm = new APMWrapper();

    this._globalSearch = "";
    this._installedSearch = "";
    this._installing = {};
    this._featured = {
      themes: [],
      packages: [],
    };
    this._newerVersions = [];
    this._searchResults = null;
    this._refreshFeatured();

    this.listenTo(PluginsActions.refreshFeaturedPackages, this._refreshFeatured);
    this.listenTo(PluginsActions.refreshInstalledPackages, this._refreshInstalled);

    NylasEnv.commands.add(document.body,
      'application:create-package',
      () => this._onCreatePackage()
    );

    NylasEnv.commands.add(document.body,
      'application:install-package',
      () => this._onInstallPackage()
    );

    this.listenTo(PluginsActions.installNewPackage, this._onInstallPackage);
    this.listenTo(PluginsActions.createPackage, this._onCreatePackage);
    this.listenTo(PluginsActions.updatePackage, this._onUpdatePackage);
    this.listenTo(PluginsActions.setGlobalSearchValue, this._onGlobalSearchChange);
    this.listenTo(PluginsActions.setInstalledSearchValue, this._onInstalledSearchChange);

    this.listenTo(PluginsActions.showPackage, (pkg) => {
      const dir = NylasEnv.packages.resolvePackagePath(pkg.name);
      if (dir) shell.showItemInFolder(dir);
    });

    this.listenTo(PluginsActions.installPackage, (pkg) => {
      this._installing[pkg.name] = true;
      this.trigger(this);
      this._apm.install(pkg, (err) => {
        if (err) {
          delete this._installing[pkg.name];
          this._displayMessage("Sorry, an error occurred", err.toString());
        } else {
          if (NylasEnv.packages.isPackageDisabled(pkg.name)) {
            NylasEnv.packages.enablePackage(pkg.name);
          }
        }
        this._onPackagesChanged();
      });
    });

    this.listenTo(PluginsActions.uninstallPackage, (pkg) => {
      if (NylasEnv.packages.isPackageLoaded(pkg.name)) {
        NylasEnv.packages.disablePackage(pkg.name);
        NylasEnv.packages.unloadPackage(pkg.name);
      }
      this._apm.uninstall(pkg, (err) => {
        if (err) this._displayMessage("Sorry, an error occurred", err.toString())
        this._onPackagesChanged();
      })
    });

    this.listenTo(PluginsActions.enablePackage, (pkg) => {
      if (NylasEnv.packages.isPackageDisabled(pkg.name)) {
        NylasEnv.packages.enablePackage(pkg.name);
        this._onPackagesChanged();
      }
    });

    this.listenTo(PluginsActions.disablePackage, (pkg) => {
      if (!NylasEnv.packages.isPackageDisabled(pkg.name)) {
        NylasEnv.packages.disablePackage(pkg.name);
        this._onPackagesChanged();
      }
    });

    this._hasPrepared = false;
  },

  // Getters

  installed: function installed() {
    this._prepareIfFresh();
    return this._addPackageStates(this._filter(this._installed, this._installedSearch));
  },

  installedSearchValue: function installedSearchValue() {
    return this._installedSearch;
  },

  featured: function featured() {
    this._prepareIfFresh();
    return this._addPackageStates(this._featured);
  },

  searchResults: function searchResults() {
    return this._addPackageStates(this._searchResults);
  },

  globalSearchValue: function globalSearchValue() {
    return this._globalSearch;
  },

  // Action Handlers

  _prepareIfFresh: function _prepareIfFresh() {
    if (this._hasPrepared) return;
    NylasEnv.packages.onDidActivatePackage(() => this._onPackagesChangedDebounced());
    NylasEnv.packages.onDidDeactivatePackage(() => this._onPackagesChangedDebounced());
    NylasEnv.packages.onDidLoadPackage(() => this._onPackagesChangedDebounced());
    NylasEnv.packages.onDidUnloadPackage(() => this._onPackagesChangedDebounced());
    this._onPackagesChanged();
    this._hasPrepared = true;
  },

  _filter: function _filter(hash, search) {
    const result = {}
    const query = search.toLowerCase();
    if (hash) {
      Object.keys(hash).forEach((key) => {
        result[key] = _.filter(hash[key], (p) =>
          query.length === 0 || p.name.toLowerCase().indexOf(query) !== -1
        );
      });
    }
    return result;
  },

  _refreshFeatured: function _refreshFeatured() {
    this._apm.getFeatured({themes: false})
    .then((results) => {
      this._featured.packages = results;
      this.trigger();
    })
    .catch(() => {
      // We may be offline
    });
    this._apm.getFeatured({themes: true})
    .then((results) => {
      this._featured.themes = results;
      this.trigger();
    })
    .catch(() => {
      // We may be offline
    });
  },

  _refreshInstalled: function _refreshInstalled() {
    this._onPackagesChanged();
  },

  _refreshSearch: function _refreshSearch() {
    if (!this._globalSearch || this._globalSearch.length <= 0) return;

    this._apm.search(this._globalSearch)
    .then((results) => {
      this._searchResults = {
        packages: results.filter(({theme}) => !theme),
        themes: results.filter(({theme}) => theme),
      }
      this.trigger();
    })
    .catch(() => {
      // We may be offline
    });
  },

  _refreshSearchThrottled: function _refreshSearchThrottled() {
    _.debounce(this._refreshSearch, 400)
  },

  _onPackagesChanged: function _onPackagesChanged() {
    this._apm.getInstalled()
    .then((packages) => {
      for (const category of ['dev', 'user']) {
        packages[category].forEach((pkg) => {
          pkg.category = category;
          delete this._installing[pkg.name];
        });
      }

      const available = NylasEnv.packages.getAvailablePackageMetadata();
      const examples = available.filter(({isOptional, isHiddenOnPluginsPage}) =>
        isOptional && !isHiddenOnPluginsPage);
      packages.example = examples.map((pkg) =>
        _.extend({}, pkg, {installed: true, category: 'example'})
      );
      this._installed = packages;
      this.trigger();
    });
  },

  _onPackagesChangedDebounced: function _onPackagesChangedDebounced() {
    _.debounce(this._onPackagesChanged, 200);
  },

  _onInstalledSearchChange: function _onInstalledSearchChange(val) {
    this._installedSearch = val;
    this.trigger();
  },

  _onUpdatePackage: function _onUpdatePackage(pkg) {
    this._apm.update(pkg, pkg.newerVersion);
  },

  _onInstallPackage: function _onInstallPackage() {
    NylasEnv.showOpenDialog({
      title: "Choose a Plugin Directory",
      buttonLabel: 'Choose',
      properties: ['openDirectory'],
    },
    (filenames) => {
      if (!filenames || filenames.length === 0) return;
      NylasEnv.packages.installPackageFromPath(filenames[0], (err, packageName) => {
        if (err) {
          this._displayMessage("Could not install plugin", err.message);
        } else {
          this._onPackagesChanged();
          const msg = `${packageName} has been installed and enabled. No need to restart! If you don't see the plugin loaded, check the console for errors.`
          this._displayMessage("Plugin installed! 🎉", msg);
        }
      });
    });
  },

  _onCreatePackage: function _onCreatePackage() {
    if (!NylasEnv.inDevMode()) {
      const btn = dialog.showMessageBox({
        type: 'warning',
        message: "Run with debug flags?",
        detail: `To develop plugins, you should run N1 with debug flags. This gives you better error messages, the debug version of React, and more. You can disable it at any time from the Developer menu.`,
        buttons: ["OK", "Cancel"],
      });
      if (btn === 0) {
        ipcRenderer.send('command', 'application:toggle-dev');
      }
      return;
    }

    const packagesDir = path.join(NylasEnv.getConfigDirPath(), 'dev', 'packages');
    fs.makeTreeSync(packagesDir);

    NylasEnv.showSaveDialog({
      title: "Save New Package",
      defaultPath: packagesDir,
      properties: ['createDirectory'],
    }, (packageDir) => {
      if (!packageDir) return;

      const packageName = path.basename(packageDir);

      if (!packageDir.startsWith(packagesDir)) {
        this._displayMessage('Invalid plugin location',
          'Sorry, you must create plugins in the packages folder.');
      }

      if (NylasEnv.packages.resolvePackagePath(packageName)) {
        this._displayMessage('Invalid plugin name',
          'Sorry, you must give your plugin a unique name.');
      }

      if (packageName.indexOf(' ') !== -1) {
        this._displayMessage('Invalid plugin name',
          'Sorry, plugin names cannot contain spaces.');
      }

      fs.mkdir(packageDir, (err) => {
        if (err) {
          this._displayMessage('Could not create plugin', err.toString());
          return;
        }
        const {resourcePath} = NylasEnv.getLoadSettings();
        const packageTemplatePath = path.join(resourcePath, 'static', 'package-template');
        const packageJSON = {
          name: packageName,
          main: "./lib/main",
          version: '0.1.0',
          repository: {
            type: 'git',
            url: '',
          },
          engines: {
            nylas: `>=${NylasEnv.getVersion().split('-')[0]}`,
          },
          windowTypes: {
            'default': true,
            'composer': true,
          },
          description: "Enter a description of your package!",
          dependencies: {},
          license: "MIT",
        };

        fs.copySync(packageTemplatePath, packageDir);
        fs.writeFileSync(path.join(packageDir, 'package.json'), JSON.stringify(packageJSON, null, 2));
        shell.showItemInFolder(packageDir);
        _.defer(() => {
          NylasEnv.packages.enablePackage(packageDir);
          NylasEnv.packages.activatePackage(packageName);
        });
      });
    });
  },

  _onGlobalSearchChange: function _onGlobalSearchChange(val) {
    // Clear previous search results data if this is a new
    // search beginning from "".
    if (this._globalSearch.length === 0 && val.length > 0) {
      this._searchResults = null;
    }

    this._globalSearch = val;
    this._refreshSearchThrottled();
    this.trigger();
  },

  _addPackageStates: function _addPackageStates(pkgs) {
    const installedNames = _.flatten(_.values(this._installed)).map((pkg) => pkg.name);

    _.flatten(_.values(pkgs)).forEach((pkg) => {
      pkg.enabled = !NylasEnv.packages.isPackageDisabled(pkg.name);
      pkg.installed = installedNames.indexOf(pkg.name) !== -1;
      pkg.installing = this._installing[pkg.name];
      pkg.newerVersionAvailable = this._newerVersions[pkg.name];
      pkg.newerVersion = this._newerVersions[pkg.name];
    });

    return pkgs;
  },

  _displayMessage: function _displayMessage(title, message) {
    dialog.showMessageBox({
      type: 'warning',
      message: title,
      detail: message,
      buttons: ["OK"],
    });
  },

});

export default PackagesStore;
