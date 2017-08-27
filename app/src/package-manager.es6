import path from 'path';
import fs from 'fs';

import Package from './package';

export default class PackageManager {
  constructor({configDirPath, devMode, safeMode, resourcePath, specMode}) {
    this.packageDirectories = [];

    this.available = {};
    this.active = {};
    this.waiting = [];

    if (specMode) {
      this.packageDirectories.push(path.join(resourcePath, "spec", "fixtures", "packages"));
    } else {
      this.packageDirectories.push(path.join(resourcePath, "internal_packages"));
      if (!safeMode) {
        this.packageDirectories.push(path.join(configDirPath, "packages"))
        if (devMode) {
          this.packageDirectories.push(path.join(configDirPath, "dev", "packages"))
        }
      }
    }

    this.discoverPackages();
  }

  pluginIdFor(packageName) {
    // Plugin IDs are now package names - the ID concept was complicated and nobody got it.
    return packageName
  }

  discoverPackages() {
    for (const dir of this.packageDirectories) {
      let filenames = [];
      try {
        filenames = fs.readdirSync(dir);
      } catch (err) {
        continue;
      }

      for (const filename of filenames) {
        let pkg = null;
        try {
          pkg = new Package(path.join(dir, filename));
          this.available[pkg.name] = pkg;
        } catch (err) {
          if (err instanceof Package.NoPackageJSONError) {
            continue;
          }
          const wrapped = new Error(`Unable to read package.json for ${filename}: ${err.toString()}`);
          NylasEnv.reportError(wrapped);
        }
      }
    }
  }

  activatePackages(windowType) {
    const disabled = NylasEnv.config.get('core.disabledPackages');

    for (const name of Object.keys(this.available)) {
      const pkg = this.available[name];

      if (this.active[pkg.name]) {
        continue;
      }

      if (!pkg || pkg.isTheme()) {
        continue;
      }

      if (pkg.isOptional() && disabled.includes(pkg.name)) {
        continue;
      }

      if (!pkg.json.engines.merani) {
        // don't use NylasEnv.reportError, I don't want to know about these.
        console.error(`The package ${pkg.name} does not list "merani" in it's package.json's "engines" field. Ask the developer to test the plugin with Merani and add it.`);
        continue;
      }

      if (pkg.windowTypes[windowType]) {
        if (pkg.syncInit) {
          this.activatePackage(pkg);
        } else {
          this.waiting.push(pkg);
        }
      }
    }

    setTimeout(() => {
      for (const w of this.waiting) {
        this.activatePackage(w);
      }
      this.waiting = [];
    }, 2500);
  }

  activatePackage(pkg) {
    this.active[pkg.name] = pkg;
    pkg.activate();
  }

  deactivatePackages() {

  }

  getAvailablePacakges() {
    return Object.values(this.available);
  }

  getActivePackages() {
    return Object.values(this.active);
  }

  getPackageNamed(packagename) {
    return this.available[packagename];
  }
}
