/* eslint global-require: 0 */

import _ from 'underscore'

import NylasStore from 'nylas-store'
import KeyManager from '../../key-manager'
import Actions from '../actions'
import Account from '../models/account'
import Utils from '../models/utils'

const configAccountsKey = "accounts"
const configVersionKey = "accountsVersion"


/*
Public: The AccountStore listens to changes to the available accounts in
the database and exposes the currently active Account via {::current}

Section: Stores
*/
class AccountStore extends NylasStore {

  constructor(props) {
    super(props)
    this._loadAccounts();
    this.listenTo(Actions.removeAccount, this._onRemoveAccount)
    this.listenTo(Actions.updateAccount, this._onUpdateAccount)
    this.listenTo(Actions.reorderAccount, this._onReorderAccount)

    NylasEnv.config.onDidChange(configVersionKey, async (change) => {
      // If we already have this version of the accounts config, it means we
      // are the ones who saved the change, and we don't need to reload.
      if (this._version / 1 === change.newValue / 1) {
        return;
      }

      const oldAccountIds = this._accounts.map(a => a.id)
      this._loadAccounts()
      const accountIds = this._accounts.map(a => a.id)
      const newAccountIds = _.difference(accountIds, oldAccountIds)

      if (NylasEnv.isMainWindow() && newAccountIds.length > 0) {
        const newId = newAccountIds[0]
        Actions.focusDefaultMailboxPerspectiveForAccounts([newId], {sidebarAccountIds: accountIds})
        const FolderSyncProgressStore = require('./folder-sync-progress-store').default
        await FolderSyncProgressStore.whenCategoryListSynced(newId)
        Actions.focusDefaultMailboxPerspectiveForAccounts([newId], {sidebarAccountIds: accountIds})
        // TODO:
        // This Action is a hack, get rid of it in sidebar refactor
        // Wait until the FocusedPerspectiveStore triggers and the sidebar is
        // updated to uncollapse the inbox for the new account
        Actions.setCollapsedSidebarItem('Inbox', false)
      }
    })
  }

  isMyEmail(emailOrEmails = []) {
    const myEmails = this.emailAddresses()
    let emails = emailOrEmails;
    if (typeof emails === 'string') {
      emails = [emailOrEmails];
    }
    for (const email of emails) {
      if (myEmails.find((myEmail) => Utils.emailIsEquivalent(myEmail, email))) {
        return true;
      }
    }
    return false
  }

  _loadAccounts = () => {
    try {
      this._caches = {}
      this._version = NylasEnv.config.get(configVersionKey) || 0
      this._accounts = []
      for (const json of NylasEnv.config.get(configAccountsKey) || []) {
        this._accounts.push((new Account()).fromJSON(json))
      }

      // Run a few checks on account consistency. We want to display useful error
      // messages and these can result in very strange exceptions downstream otherwise.
      this._enforceAccountsValidity();
    } catch (error) {
      NylasEnv.reportError(error)
    }

    this._trigger()
  }

  _enforceAccountsValidity = () => {
    const seenIds = {}
    const seenEmails = {}
    let message = null

    this._accounts = this._accounts.filter((account) => {
      if (!account.emailAddress) {
        message = "Assertion failure: One of the accounts in config.json did not have an emailAddress, and was removed. You should re-link the account."
        return false
      }
      if (seenIds[account.id]) {
        message = "Assertion failure: Two of the accounts in config.json had the same ID and one was removed. Please give each account a separate ID."
        return false
      }
      if (seenEmails[account.emailAddress]) {
        message = "Assertion failure: Two of the accounts in config.json had the same email address and one was removed."
        return false
      }

      seenIds[account.id] = true
      seenEmails[account.emailAddress] = true
      return true
    })

    if (message && NylasEnv.isMainWindow()) {
      NylasEnv.showErrorDialog(`N1 was unable to load your account preferences.\n\n${message}`)
    }
  }

  _trigger() {
    for (const account of this._accounts) {
      if (!account || !account.id) {
        const err = new Error("An invalid account was added to `this._accounts`")
        NylasEnv.reportError(err)
        this._accounts = _.compact(this._accounts)
      }
    }
    this.trigger()
  }

  _save = () => {
    this._version += 1;
    const configAccounts = this._accounts.map(a => a.toJSON());
    configAccounts.forEach(a => {
      delete a.sync_error

      // this should not be necessary since this info is stripped when
      // the account is added, but we want to be on the safe side.
      delete a.settings.imap_password;
      delete a.settings.smtp_password;
      delete a.settings.refresh_token;
    });
    NylasEnv.config.set(configAccountsKey, configAccounts);
    NylasEnv.config.set(configVersionKey, this._version);
    this._trigger()
  }

  /**
   * Actions.updateAccount is called directly from the local-sync worker.
   * This will update the account with its updated sync state
   */
  _onUpdateAccount = (id, updated) => {
    const idx = this._accounts.findIndex((a) => a.id === id)
    let account = this._accounts[idx]
    if (!account) return
    account = Object.assign(account, updated)
    this._caches = {}
    this._accounts[idx] = account
    this._save()
  }

  /**
   * When an account is removed from Mailspring, the AccountStore
   * triggers. The local-sync/src/local-sync-worker/index.js listens to
   * the AccountStore and runs `ensureK2Consistency`. This will actually
   * delete the Account on the local sync side.
   */
  _onRemoveAccount = (id) => {
    const account = this._accounts.find(a => a.id === id);
    if (!account) return
    KeyManager.deleteAccountSecrets(account)

    this._caches = {}

    const remainingAccounts = this._accounts.filter((a) => a !== account);
    // This action is called before saving because we need to unfocus the
    // perspective of the account that is being removed before removing the
    // account, otherwise when we trigger with the new set of accounts, the
    // current perspective will still reference a stale accountId which will
    // cause things to break
    Actions.focusDefaultMailboxPerspectiveForAccounts(remainingAccounts)
    _.defer(() => {
      Actions.setCollapsedSidebarItem('Inbox', true)
    })

    this._accounts = remainingAccounts
    this._save()

    if (remainingAccounts.length === 0) {
      const ipc = require('electron').ipcRenderer
      ipc.send('command', 'application:relaunch-to-initial-windows', {
        resetDatabase: true,
      })
    }
  }

  _onReorderAccount = (id, newIdx) => {
    const existingIdx = this._accounts.findIndex((a) => a.id === id);
    if (existingIdx === -1) return
    const account = this._accounts[existingIdx]
    this._caches = {}
    this._accounts.splice(existingIdx, 1)
    this._accounts.splice(newIdx, 0, account)
    this._save()
  }

  addAccount = (account) => {
    if (!account.emailAddress || !account.provider || !(account instanceof Account)) {
      throw new Error(`Returned account data is invalid: ${JSON.stringify(account)}`)
    }

    // send the account JSON and cloud token to the KeyManager,
    // which gives us back a version with no secrets.
    const cleanAccount = KeyManager.extractAccountSecrets(account);

    this._loadAccounts();

    const existingIdx = this._accounts.findIndex((a) =>
      a.id === cleanAccount.id || a.emailAddress === cleanAccount.emailAddress
    );

    if (existingIdx === -1) {
      this._accounts.push(cleanAccount);
    } else {
      const existing = this._accounts[existingIdx];
      existing.syncState = Account.SYNC_STATE_OK;
      existing.name = cleanAccount.name;
      existing.emailAddress = cleanAccount.emailAddress;
      existing.settings = cleanAccount.settings;
    }

    this._save();
  }

  _cachedGetter(key, fn) {
    this._caches[key] = this._caches[key] || fn()
    return this._caches[key]
  }

  // Public: Returns an {Array} of {Account} objects
  accounts = () => {
    return this._accounts
  }

  accountIds = () => {
    return this._accounts.map(a => a.id);
  }

  accountsForItems = (items) => {
    const accounts = {}
    items.forEach(({accountId}) => {
      accounts[accountId] = accounts[accountId] || this.accountForId(accountId)
    })
    return _.compact(Object.values(accounts))
  }

  accountForItems = (items) => {
    const accounts = this.accountsForItems(items)
    if (accounts.length > 1) return null
    return accounts[0]
  }

  // Public: Returns the {Account} for the given email address, or null.
  accountForEmail = (email) => {
    for (const account of this.accounts()) {
      if (Utils.emailIsEquivalent(email, account.emailAddress)) {
        return account
      }
    }
    for (const alias of this.aliases()) {
      if (Utils.emailIsEquivalent(email, alias.email)) {
        return this.accountForId(alias.accountId)
      }
    }
    return null
  }

  // Public: Returns the {Account} for the given account id, or null.
  accountForId(id) {
    return this._cachedGetter(`accountForId:${id}`, () => this._accounts.find(a => a.id === id));
  }

  emailAddresses() {
    let addresses = (this.accounts() ? this.accounts() : []).map(a => a.emailAddress);
    addresses = addresses.concat((this.aliases() ? this.aliases() : []).map(a => a.email));
    return _.unique(addresses)
  }

  aliases() {
    return this._cachedGetter("aliases", () => {
      const aliases = []
      for (const acc of this._accounts) {
        aliases.push(acc.me())
        for (const alias of acc.aliases) {
          const aliasContact = acc.meUsingAlias(alias)
          aliasContact.isAlias = true
          aliases.push(aliasContact)
        }
      }
      return aliases
    })
  }

  aliasesFor(accountsOrIds) {
    const ids = accountsOrIds.map((accOrId) => {
      return accOrId instanceof Account ? accOrId.id : accOrId
    })
    return this.aliases().filter((contact) => ids.includes(contact.accountId))
  }

  // Public: Returns the currently active {Account}.
  current() {
    throw new Error("AccountStore.current() has been deprecated.")
  }
}

export default new AccountStore()
