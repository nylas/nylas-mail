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
    this.SERVICE_NAME = "Merani";
    if (NylasEnv.inDevMode()) {
      this.SERVICE_NAME = "Merani Dev";
    }
    this.KEY_NAME = "Merani Keys"
  }

  extractAccountSecrets(accountJSON, cloudToken) {
    const next = Object.assign({}, accountJSON);
    this._try(() => {
      const keys = this._getKeyHash();
      keys[`${accountJSON.emailAddress}-imap`] = next.settings.imap_password;
      delete next.settings.imap_password;
      keys[`${accountJSON.emailAddress}-smtp`] = next.settings.smtp_password;
      delete next.settings.smtp_password;
      keys[`${accountJSON.emailAddress}-refresh-token`] = next.settings.xoauth_refresh_token;
      delete next.settings.xoauth_refresh_token;
      keys[`${accountJSON.emailAddress}-cloud`] = cloudToken;
      return this._writeKeyHash(keys);
    });
    return next;
  }

  insertAccountSecrets(accountJSON) {
    const next = Object.assign({}, accountJSON);
    const keys = this._getKeyHash();
    next.settings.imap_password = keys[`${accountJSON.emailAddress}-imap`];
    next.settings.smtp_password = keys[`${accountJSON.emailAddress}-smtp`];
    next.settings.xoauth_refresh_token = keys[`${accountJSON.emailAddress}-refresh-token`];
    next.cloudToken = keys[`${accountJSON.emailAddress}-cloud`];
    return next;
  }

  replacePassword(keyName, newVal) {
    this._try(() => {
      const keys = this._getKeyHash();
      keys[keyName] = newVal;
      return this._writeKeyHash(keys);
    })
  }

  deletePassword(keyName) {
    this._try(() => {
      const keys = this._getKeyHash();
      delete keys[keyName];
      return this._writeKeyHash(keys);
    })
  }

  getPassword(keyName) {
    const keys = this._getKeyHash();
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

  _writeKeyHash(keys) {
    // returns true if successful
    return keytar.replacePassword(this.SERVICE_NAME, this.KEY_NAME, JSON.stringify(keys));
  }

  _try(fn) {
    const ERR_MSG = "We couldn't store your password securely! For more information, visit https://support.getmerani.com/hc/en-us/articles/223790028";
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
