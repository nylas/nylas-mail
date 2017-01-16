/* eslint global-require:0 */
/* eslint import/no-dynamic-require:0 */
import fs from 'fs'
import path from 'path'
import keytar from 'keytar'
import Sqlite3 from 'better-sqlite3';

/**
 * On Jan 17, 2017 we launched Nylas Mail Basic. This had the K2 project
 * to do local sync in the mail client.
 *
 * At launch old N1 was more feature-rich and deemed "Nylas Pro". For a
 * while after launch people could download Nylas Mail Basic and "upgrade"
 * to "Nylas Pro". This attempts to migrate as many settings as possible
 * between versions.
 *
 * This gets run immediately after Config gets setup.
 *
 */
class NylasProMigrator {
  migrate(config, configDirPath) {
    this.config = config;
    this.configDirPath = configDirPath
    if (!this._shouldMigrate()) return;
    this.config.set("nylasMailBasicMigrationTime", Date.now())
    this._migrateConfig()
    this._migrateKeychain()
  }

  _shouldMigrate() {
    return fs.existsSync(this._basicConfigPath()) && !this.config.get("nylasMailBasicMigrationTime")
  }

  _shouldMigrateMailRules() {
    return !this.config.get("nylasMailBasicMigrationMailRulesTime")
  }

  _basicConfigPath() {
    return path.join(this.configDirPath, '..', '.nylas-mail')
  }

  _migrateConfig() {
    console.log("---> Migrating config from Nylas Mail Basic")
    try {
      // NOTE: If the config doesn't exist this will throw and not
      // migrate.
      const oldConfig = require(path.join(this._basicConfigPath(), "config.json"))["*"] || {}
      for (const key of Object.keys(oldConfig)) {
        if (key === "nylas" && oldConfig[key]) {
          delete oldConfig[key].accounts
          delete oldConfig[key].accountsVersion
        }
        if (key === "core" && oldConfig[key]) {
          if (oldConfig.core.disabledPackages) {
            const defaultJSON = require("../../dot-nylas/config.json");
            const disabled = defaultJSON["*"].core.disabledPackages;
            oldConfig.core.disabledPackages = disabled
          }
        }
        // Safe to do since no one is listening to the config yet
        this.config.set(key, oldConfig[key]);
      }
    } catch (err) {
      console.error(err);
      // dont' throw
    }
  }

  /**
   * We store the Nylas ID token in the keychain. This is the only one we
   * move over since the accounts' tokens are for the local-sync DB.
   */
  _migrateKeychain() {
    console.log("---> Migrating keychain from Nylas Mail Basic")
    try {
      const raw = keytar.getPassword("Nylas Mail", "Nylas Mail Keys") || "{}";
      const passwords = JSON.parse(raw);
      const token = passwords["Nylas Account"]
      if (token) {
        keytar.replacePassword("Nylas", "Nylas Account", token)
      }
    } catch (err) {
      console.error(err);
      // dont' throw
    }
  }

  /**
   * TODO: We don't have MailRules yet in Nylas Basic. Add this in when we
   * get mail rules. It will have to be called from the Main Window of
   * NylasEnv after the stores have been setup. This is different from the
   * other functions that are called during backend browser/application
   * setup.
   */
  migrateMailRules() {
    console.log("---> Migrating mail rules from Nylas Mail Basic");
    try {
      const basicDB = new Sqlite3(path.join(this._basicConfigPath(), "edgehill.db"), {});
      basicDB.on('open', () => {
        try {
          const query = "SELECT * FROM JSONBlob WHERE id='MailRules-V2'";
          const row = this._db.prepare(query).get();
          if (row && row.data) {
            const mailRules = JSON.parse(row.data);
            const DatabaseStore = require('../flux/stores/database-store').default
            DatabaseStore.inTransaction((t) => {
              return t.persistJSONBlob("MailRules-V2", mailRules)
            });
          } else {
            console.log("---> No mail rules found")
          }
          basicDB.close()
        } catch (err) {
          console.error(err);
          basicDB.close()
        }
      })
    } catch (err) {
      console.error(err);
      // dont' throw
    }
    this.config.set("nylasMailBasicMigrationMailRulesTime", Date.now())
  }
}

export default new NylasProMigrator()
