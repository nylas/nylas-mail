/* eslint global-require: 0 */

import _ from 'underscore'

import NylasStore from 'nylas-store'
import KeyManager from '../../key-manager'
import Actions from '../actions'
import Account from '../models/account'
import Utils from '../models/utils'
import DatabaseStore from './database-store'

const configAccountsKey = "nylas.accounts"
const configVersionKey = "nylas.accountsVersion"


/*
Public: The AccountStore listens to changes to the available accounts in
the database and exposes the currently active Account via {::current}

Section: Stores
*/
class AccountStore extends NylasStore {

  constructor(props) {
    super(props)
    this._loadAccounts()
    this.listenTo(Actions.removeAccount, this._onRemoveAccount)
    this.listenTo(Actions.updateAccount, this._onUpdateAccount)
    this.listenTo(Actions.reorderAccount, this._onReorderAccount)
    this.listenTo(Actions.apiAuthError, this._onAPIAuthError)

    NylasEnv.config.onDidChange(configVersionKey, async (change) => {
      // If we already have this version of the accounts config, it means we
      // are the ones who saved the change, and we don't need to reload.
      if (this._version / 1 === change.newValue / 1) {
        return;
      }

      const oldAccountIds = _.pluck(this._accounts, 'id')
      this._loadAccounts()
      const accountIds = _.pluck(this._accounts, 'id')
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
      if (_.any(myEmails, (myEmail) => Utils.emailIsEquivalent(myEmail, email))) {
        return true;
      }
    }
    return false
  }

  _onAPIAuthError = (apiError, apiOptions, apiName) => {
    // Prevent /auth errors from presenting auth failure notices
    const apiToken = apiOptions.auth.user
    if (!apiToken) {
      return Promise.resolve()
    }

    const account = this.accounts().find((acc) => {
      const tokens = this.tokensForAccountId(acc.id);
      if (!tokens) return false
      const localMatch = tokens.localSync === apiToken;
      const cloudMatch = tokens.n1Cloud === apiToken;
      return localMatch || cloudMatch;
    })

    if (account) {
      if (apiName === "N1CloudAPI") {
        const n1CloudState = Account.N1_CLOUD_STATE_AUTH_FAILED
        this._onUpdateAccount(account.id, {n1CloudState})
      } else {
        const syncState = Account.SYNC_STATE_AUTH_FAILED
        this._onUpdateAccount(account.id, {syncState})
      }
    }
    return Promise.resolve()
  }

  _loadAccounts = () => {
    try {
      this._caches = {}
      this._tokens = this._tokens || {};
      this._version = NylasEnv.config.get(configVersionKey) || 0

      const oldAccountIds = _.pluck(this._accounts, 'id')
      this._accounts = []
      for (const json of NylasEnv.config.get(configAccountsKey) || []) {
        this._accounts.push((new Account()).fromJSON(json))
      }
      const accountIds = _.pluck(this._accounts, 'id')

      // Loading passwords from the KeyManager is expensive so only do it if
      // we really have to (i.e. we're loading a new Account)
      const addedAccountIds = _.difference(accountIds, oldAccountIds);
      const addedAccounts = _.filter(this._accounts, (a) => addedAccountIds.includes(a.id));
      const removedAccountIds = _.difference(oldAccountIds, accountIds);
      const removedAccounts = _.filter(this._accounts, (a) => removedAccountIds.includes(a.id));

      // Run a few checks on account consistency. We want to display useful error
      // messages and these can result in very strange exceptions downstream otherwise.
      this._enforceAccountsValidity()

      for (const account of addedAccounts) {
        const credentials = {
          n1Cloud: KeyManager.getPassword(`${account.emailAddress}.n1Cloud`, {migrateFromService: "Nylas"}),
          localSync: KeyManager.getPassword(`${account.emailAddress}.localSync`, {migrateFromService: "Nylas"}),
        }
        this._tokens[account.id] = credentials;

        // TODO HACK. For some reason we're getting passed the wrong
        // id. Figure this out after launch.
        this._tokens[account.emailAddress] = credentials;
      }
      for (const removedAccount of removedAccounts) {
        const {id, emailAddress} = removedAccount
        if (this._tokens[id]) {
          delete this._tokens[id]
        }
        if (this._tokens[emailAddress]) {
          delete this._tokens[emailAddress]
        }
      }
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
    this._version += 1
    const configAccounts = this._accounts.map(a => a.toJSON())
    configAccounts.forEach(a => delete a.sync_error)
    NylasEnv.config.set(configAccountsKey, configAccounts)
    NylasEnv.config.set(configVersionKey, this._version)
    this._trigger()
  }

  /**
   * Actions.updateAccount is called directly from the local-sync worker.
   * This will update the account with its updated sync state
   */
  _onUpdateAccount = (id, updated) => {
    const idx = _.findIndex(this._accounts, (a) => a.id === id)
    let account = this._accounts[idx]
    if (!account) return
    account = _.extend(account, updated)
    this._caches = {}
    this._accounts[idx] = account
    this._save()
  }

  /**
   * When an account is removed from Nylas Mail, the AccountStore
   * triggers. The local-sync/src/local-sync-worker/index.js listens to
   * the AccountStore and runs `ensureK2Consistency`. This will actually
   * delete the Account on the local sync side.
   */
  _onRemoveAccount = (id) => {
    const account = _.findWhere(this._accounts, {id})
    if (!account) return
    KeyManager.deletePassword(account.emailAddress)

    this._caches = {}

    const remainingAccounts = _.without(this._accounts, account)
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
    const existingIdx = _.findIndex(this._accounts, (a) => a.id === id)
    if (existingIdx === -1) return
    const account = this._accounts[existingIdx]
    this._caches = {}
    this._accounts.splice(existingIdx, 1)
    this._accounts.splice(newIdx, 0, account)
    this._save()
  }

  addAccountFromJSON = (json, localToken, cloudToken) => {
    if (!json.email_address || !json.provider) {
      console.error("Returned account data is invalid", json)
      console.log(JSON.stringify(json))
      throw new Error("Returned account data is invalid")
    }

    this._loadAccounts()

    this._tokens[json.id] = {
      n1Cloud: cloudToken,
      localSync: localToken,
    }
    KeyManager.replacePassword(`${json.email_address}.n1Cloud`, cloudToken)
    KeyManager.replacePassword(`${json.email_address}.localSync`, localToken)

    const existingIdx = _.findIndex(this._accounts, (a) =>
      a.id === json.id || a.emailAddress === json.email_address
    )

    if (existingIdx === -1) {
      const account = (new Account()).fromJSON(json)
      this._accounts.push(account)
    } else {
      const account = this._accounts[existingIdx]
      account.syncState = Account.SYNC_STATE_RUNNING
      account.fromJSON(json)
      // Restart the connection in case account credentials have changed
      Actions.retryDeltaConnection()
    }

    this._save()
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
    return _.pluck(this._accounts, 'id')
  }

  accountsForItems = (items) => {
    const accounts = {}
    items.forEach(({accountId}) => {
      accounts[accountId] = accounts[accountId] || this.accountForId(accountId)
    })
    return _.compact(_.values(accounts))
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
    return this._cachedGetter(`accountForId:${id}`, () => _.findWhere(this._accounts, {id}))
  }

  accountIsSyncing(accountId) {
    const account = this.accountForId(accountId)
    return !account.hasSyncStateError()
  }

  accountsAreSyncing() {
    return this.accounts().every(acc => !acc.hasSyncStateError())
  }

  emailAddresses() {
    let addresses = _.pluck((this.accounts() ? this.accounts() : []), "emailAddress")
    addresses = addresses.concat(_.pluck((this.aliases() ? this.aliases() : []), "email"))
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

  // Private: This method is going away soon, do not rely on it.
  tokensForAccountId(id) {
    return this._tokens[id]
  }

  // Private: Load fake data from a directory for taking nice screenshots
  _importFakeData = (dir) => {
    const fs = require('fs-plus')
    const path = require('path')
    const Message = require('../models/message').default
    const Thread = require('../models/thread').default

    this._caches = {}

    let labels = []
    const threads = []
    let messages = []

    let account = this.accountForEmail('nora@nylas.com')
    if (!account) {
      account = new Account()
      account.serverId = account.clientId
      account.emailAddress = "nora@nylas.com"
      account.organizationUnit = 'label'
      account.label = "Nora's Email"
      account.aliases = []
      account.name = "Nora"
      account.provider = "gmail"
      const json = account.toJSON()
      json.token = 'nope'
      this.addAccountFromJSON(json)
    }

    const filenames = fs.readdirSync(path.join(dir, 'threads'))
    for (const filename of filenames) {
      const threadJSON = fs.readFileSync(path.join(dir, 'threads', filename))
      const threadMessages = JSON.parse(threadJSON).map((j) => (new Message()).fromJSON(j))
      let threadLabels = []
      let threadParticipants = []
      let threadAttachment = false
      let threadUnread = false

      for (const m of threadMessages) {
        m.accountId = account.id
        for (const l of m.categories) {
          l.accountId = account.id
        }
        for (const l of m.files) {
          l.accountId = account.id
        }
        threadParticipants = threadParticipants.concat(m.participants())
        threadLabels = threadLabels.concat(m.categories)
        threadAttachment = threadAttachment || m.files.length > 0
        threadUnread = threadUnread || m.unread
      }

      threadParticipants = _.uniq(threadParticipants, (p) => p.email)
      threadLabels = _.uniq(threadLabels, (l) => l.id)
      labels = _.uniq(labels.concat(threadLabels), (l) => l.id)

      const lastMsg = _.last(threadMessages)
      const thread = new Thread({
        accountId: account.id,
        serverId: lastMsg.threadId,
        clientId: lastMsg.threadId,
        subject: lastMsg.subject,
        lastMessageReceivedTimestamp: lastMsg.date,
        hasAttachment: threadAttachment,
        categories: threadLabels,
        participants: threadParticipants,
        unread: threadUnread,
        snippet: lastMsg.snippet,
        starred: lastMsg.starred,
      })
      messages = messages.concat(threadMessages)
      threads.push(thread)
    }

    const downloadsDir = path.join(dir, 'downloads')
    if (fs.existsSync(downloadsDir)) {
      for (const filename of fs.readdirSync(downloadsDir)) {
        const destPath = path.join(NylasEnv.getConfigDirPath(), 'downloads', filename)
        if (fs.existsSync(destPath)) {
          fs.removeSync(destPath)
        }
        fs.copySync(path.join(downloadsDir, filename), destPath)
      }
    }

    DatabaseStore.inTransaction((t) =>
      Promise.all([
        t.persistModel(account),
        t.persistModels(labels),
        t.persistModels(messages),
        t.persistModels(threads),
      ])
    ).then(() => {
      Actions.focusDefaultMailboxPerspectiveForAccounts([account.id])
    })
    .then(() => {
      return new Promise((resolve) => setTimeout(resolve, 1000))
    })
  }
}

export default new AccountStore()
