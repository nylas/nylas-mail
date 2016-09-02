import fs from 'fs'
import path from 'path'
import semver from 'semver'


const PACKAGE_MIGRATIONS = [
  {
    "version": "0.4.50",
    "package-migrations": [{
      "new-name": "composer-markdown",
      "old-name": "N1-Markdown-Composer",
      "enabled-by-default": false,
    }],
  },
]

class PackageMigrationManager {

  constructor({config, version, configDirPath} = {}) {
    this.config = config
    this.configDirPath = configDirPath
    this.version = version
    this.savedMigrationVersion = this.config.get('core.packageMigrationVersion')
  }

  getMigrationsToRun() {
    let migrations;
    if (this.savedMigrationVersion) {
      migrations = PACKAGE_MIGRATIONS
      .filter((migration) => semver.gt(migration.version, this.savedMigrationVersion))
      .map(migration => migration['package-migrations'])
    } else {
      migrations = PACKAGE_MIGRATIONS.map(migration => migration['package-migrations'])
    }
    return [].concat.apply([], migrations)
  }

  migrate() {
    if (this.savedMigrationVersion === this.version) { return }
    const migrations = this.getMigrationsToRun()
    const oldPackNames = migrations.map((mig) => mig['old-name'])
    const disabledPackNames = this.config.get('core.disabledPackages') || []
    let oldEnabledPackNames = []

    if (fs.existsSync(path.join(this.configDirPath, 'packages'))) {
      // Find any external packages that have been manually installed
      const toMigrate = fs.readdirSync(path.join(this.configDirPath, 'packages'))
      .filter((packName) => oldPackNames.includes(packName))
      .filter((packName) => packName[0] !== '.')

      // Move old installed packages to a deprecated folder
      const deprecatedPath = path.join(this.configDirPath, 'packages-deprecated')
      if (!fs.existsSync(deprecatedPath)) {
        fs.mkdirSync(deprecatedPath);
      }
      toMigrate.forEach((packName) => {
        const prevPath = path.join(this.configDirPath, 'packages', packName)
        const nextPath = path.join(deprecatedPath, packName)
        fs.renameSync(prevPath, nextPath);
      });

      oldEnabledPackNames = toMigrate.filter((packName) => (
        !(disabledPackNames).includes(packName)
      ))
    }

    // Enable any packages that were migrated from an old install and were
    // enabled, or that should be enabled by default
    migrations.forEach((migration) => {
      // If the old install was enabled, keep it that way
      if (oldEnabledPackNames.includes(migration['old-name'])) { return }
      // If we want to enable the package by default,
      if (migration['enabled-by-default']) { return }
      const newName = migration['new-name']
      this.config.pushAtKeyPath('core.disabledPackages', newName);
    })

    this.config.set('core.packageMigrationVersion', this.version)
  }
}

export default PackageMigrationManager
