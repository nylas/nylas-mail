import {remote} from 'electron'
import keytar from 'keytar'

/**
 * A basic wrap around keytar's secure key management. Consolidates all of
 * our keys under a single namespaced keymap and provides migration
 * support.
 *
 * Consolidating this prevents a ton of key authorization popups for each
 * and every key we want to access.
 */
class KeyManager {
  constructor() {
    /**
     * NOTE: Old N1 includes a migration system that manually looks for
     * the names of these keys. If you change them be sure that old N1 is
     * fully deprecated or updated as well.
     */
    this.SERVICE_NAME = "Nylas Mail";
    if (NylasEnv.inDevMode()) {
      this.SERVICE_NAME = "Nylas Mail Dev";
    }
    this.KEY_NAME = "Nylas Mail Keys"
    this._alreadyMigrated = new Set()
  }

  replacePassword(keyName, newVal) {
    this._try(() => {
      const keys = this._getKeyHash();
      keys[keyName] = newVal;
      return keytar.replacePassword(this.SERVICE_NAME, this.KEY_NAME, JSON.stringify(keys))
    })
  }

  deletePassword(keyName) {
    this._try(() => {
      const keys = this._getKeyHash();
      delete keys[keyName];
      return keytar.replacePassword(this.SERVICE_NAME, this.KEY_NAME, JSON.stringify(keys))
    })
  }

  getPassword(keyName, {migrateFromService} = {}) {
    const keys = this._getKeyHash();
    if (!keys[keyName] && migrateFromService &&
        !this._alreadyMigrated.has(migrateFromService)) {
      const oldVal = keytar.getPassword(migrateFromService, keyName);
      if (oldVal) {
        this.replacePassword(keyName, oldVal)
        this._alreadyMigrated.add(migrateFromService)
      }
    }
    return keys[keyName]
  }

  _getKeyHash() {
    const raw = keytar.getPassword(this.SERVICE_NAME, this.KEY_NAME) || "{}";
    try {
      return JSON.parse(raw)
    } catch (err) {
      return {}
    }
  }

  _try(fn) {
    const ERR_MSG = "We couldn't store your password securely! For more information, visit https://support.nylas.com/hc/en-us/articles/223790028";
    try {
      if (!fn()) {
        remote.dialog.showErrorBox("Password Management Error", ERR_MSG)
        NylasEnv.reportError(new Error(`Password Management Error: ${ERR_MSG}`))
      }
    } catch (err) {
      remote.dialog.showErrorBox("Password Management Error", ERR_MSG)
      NylasEnv.reportError(err)
    }
  }
}
export default new KeyManager();
