import _ from 'underscore';
import Reflux from 'reflux';
import path from 'path';
import fs from 'fs-plus';
import { ipcRenderer, shell, remote } from 'electron';

import PluginsActions from './plugins-actions';

const dialog = remote.dialog;

const PackagesStore = Reflux.createStore({
  init: function init() {
    // this._globalSearch = "";
    // this._installedSearch = "";
    // this._installing = {};
    // this._featured = {
    //   themes: [],
    //   packages: [],
    // };
    // this._newerVersions = [];
    // this._searchResults = null;
    // this._refreshFeatured();
    // this.listenTo(PluginsActions.refreshFeaturedPackages, this._refreshFeatured);
    // this.listenTo(PluginsActions.refreshInstalledPackages, this._refreshInstalled);
    // this.listenTo(PluginsActions.installNewPackage, this._onInstallPackage);
    // this.listenTo(PluginsActions.createPackage, this._onCreatePackage);
    // this.listenTo(PluginsActions.updatePackage, this._onUpdatePackage);
    // this.listenTo(PluginsActions.setGlobalSearchValue, this._onGlobalSearchChange);
    // this.listenTo(PluginsActions.setInstalledSearchValue, this._onInstalledSearchChange);
    // this.listenTo(PluginsActions.showPackage, (pkg) => {
    //   const dir = AppEnv.packages.resolvePackagePath(pkg.name);
    //   if (dir) shell.showItemInFolder(dir);
    // });
    // this.listenTo(PluginsActions.installPackage, (pkg) => {
    //   this._installing[pkg.name] = true;
    //   this.trigger(this);
    //   this._apm.install(pkg, (err) => {
    //     if (err) {
    //       delete this._installing[pkg.name];
    //       this._displayMessage("Sorry, an error occurred", err.toString());
    //     } else {
    //       if (AppEnv.packages.isPackageDisabled(pkg.name)) {
    //         AppEnv.packages.enablePackage(pkg.name);
    //       }
    //     }
    //     this._onPackagesChanged();
    //   });
    // });
    // this.listenTo(PluginsActions.uninstallPackage, (pkg) => {
    //   if (AppEnv.packages.isPackageLoaded(pkg.name)) {
    //     AppEnv.packages.disablePackage(pkg.name);
    //     AppEnv.packages.unloadPackage(pkg.name);
    //   }
    //   this._apm.uninstall(pkg, (err) => {
    //     if (err) this._displayMessage("Sorry, an error occurred", err.toString())
    //     this._onPackagesChanged();
    //   })
    // });
    // this.listenTo(PluginsActions.enablePackage, (pkg) => {
    //   if (AppEnv.packages.isPackageDisabled(pkg.name)) {
    //     AppEnv.packages.enablePackage(pkg.name);
    //     this._onPackagesChanged();
    //   }
    // });
    // this.listenTo(PluginsActions.disablePackage, (pkg) => {
    //   if (!AppEnv.packages.isPackageDisabled(pkg.name)) {
    //     AppEnv.packages.disablePackage(pkg.name);
    //     this._onPackagesChanged();
    //   }
    // });
    // this._hasPrepared = false;
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
    AppEnv.packages.onDidActivatePackage(() => this._onPackagesChangedDebounced());
    AppEnv.packages.onDidDeactivatePackage(() => this._onPackagesChangedDebounced());
    AppEnv.packages.onDidLoadPackage(() => this._onPackagesChangedDebounced());
    AppEnv.packages.onDidUnloadPackage(() => this._onPackagesChangedDebounced());
    this._onPackagesChanged();
    this._hasPrepared = true;
  },

  _filter: function _filter(hash, search) {
    const result = {};
    const query = search.toLowerCase();
    if (hash) {
      Object.keys(hash).forEach(key => {
        result[key] = _.filter(
          hash[key],
          p => query.length === 0 || p.name.toLowerCase().indexOf(query) !== -1
        );
      });
    }
    return result;
  },

  _refreshFeatured: function _refreshFeatured() {
    this._apm
      .getFeatured({ themes: false })
      .then(results => {
        this._featured.packages = results;
        this.trigger();
      })
      .catch(() => {
        // We may be offline
      });
    this._apm
      .getFeatured({ themes: true })
      .then(results => {
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

    this._apm
      .search(this._globalSearch)
      .then(results => {
        this._searchResults = {
          packages: results.filter(({ theme }) => !theme),
          themes: results.filter(({ theme }) => theme),
        };
        this.trigger();
      })
      .catch(() => {
        // We may be offline
      });
  },

  _refreshSearchThrottled: function _refreshSearchThrottled() {
    _.debounce(this._refreshSearch, 400);
  },

  _onPackagesChanged: function _onPackagesChanged() {
    this._apm.getInstalled().then(packages => {
      for (const category of ['dev', 'user']) {
        packages[category].forEach(pkg => {
          pkg.category = category;
          delete this._installing[pkg.name];
        });
      }

      const available = AppEnv.packages.getAvailablePackageMetadata();
      const examples = available.filter(
        ({ isOptional, isHiddenOnPluginsPage }) => isOptional && !isHiddenOnPluginsPage
      );
      packages.example = examples.map(pkg =>
        Object.assign({}, pkg, { installed: true, category: 'example' })
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
    const installedNames = _.flatten(Object.values(this._installed)).map(pkg => pkg.name);

    _.flatten(Object.values(pkgs)).forEach(pkg => {
      pkg.enabled = !AppEnv.packages.isPackageDisabled(pkg.name);
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
      buttons: ['OK'],
    });
  },
});

export default PackagesStore;
