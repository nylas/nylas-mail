import path from 'path';
import fs from 'fs-plus';
import {setupDatabase, databasePath} from '../database-helpers'
let _ = require('underscore');
_ = _.extend(_, require('../config-utils'));

export default class ConfigPersistenceManager {
  constructor({configDirPath, resourcePath, specMode} = {}) {
    this.database = null;
    this.specMode = specMode
    this.resourcePath = resourcePath;
    this.configDirPath = configDirPath;
  }

  async setup() {
    await this._initializeDatabase();
    this._initializeConfigDirectory();
    this._migrateOldConfigs();
  }

  getRawValues() {
    if (!this._selectStatement) {
      const q = `SELECT * FROM \`config\` WHERE id = '*'`;
      this._selectStatement = this.database.prepare(q)
    }
    const row = this._selectStatement.get();
    return JSON.parse(row.data)
  }

  resetConfig(newConfig) {
    this._replace(newConfig);
  }

  setRawValue(keyPath, value) {
    const configData = this.getRawValues();
    if (!keyPath) {
      throw new Error("Must specify a keyPath to set the config")
    }

    // This edits in place
    _.setValueForKeyPath(configData, keyPath, value);

    this._replace(configData);
    return configData
  }

  _migrateOldConfigs() {
    try {
      const oldConfig = path.join(this.configDirPath, 'config.json');
      if (fs.existsSync(oldConfig)) {
        const configData = JSON.parse(fs.readFileSync(oldConfig))['*'];
        this._replace(configData)
        fs.unlinkSync(oldConfig)
      }
    } catch (err) {
      global.errorLogger.reportError(err)
    }
  }

  _replace(configData) {
    if (!this._replaceStatement) {
      const q = `REPLACE INTO \`config\` (id, data) VALUES (?,?)`;
      this._replaceStatement = this.database.prepare(q)
    }
    this._replaceStatement.run(['*', JSON.stringify(configData)])
  }

  async _initializeDatabase() {
    const dbPath = databasePath(this.configDirPath, this.specMode);
    this.database = await setupDatabase(dbPath)
    const setupQuery = `CREATE TABLE IF NOT EXISTS \`config\` (id TEXT PRIMARY KEY, data BLOB)`;
    this.database.prepare(setupQuery).run()
  }

  _initializeConfigDirectory() {
    if (!fs.existsSync(this.configDirPath)) {
      fs.makeTreeSync(this.configDirPath);
      const templateConfigDirPath = path.join(this.resourcePath, 'dot-nylas');
      fs.copySync(templateConfigDirPath, this.configDirPath);
    }
  }
}
