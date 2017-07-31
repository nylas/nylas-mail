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
    // todo bg
    return null
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
        let jsonString = null;
        let pkg = null;
        try {
          jsonString = fs.readFileSync(path.join(dir, filename, 'package.json')).toString();
        } catch (err) {
          // silently fail, not a file
        }
        if (!jsonString) {
          continue;
        }
        try {
          pkg = new Package(path.join(dir, filename), JSON.parse(jsonString));
          this.available[pkg.name] = pkg;
        } catch (err) {
          throw new Error(`Unable to read package.json for ${filename}: ${err.toString()}`);
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
