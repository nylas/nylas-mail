_ = require 'underscore'
NylasStore = require 'nylas-store'
Actions = require '../actions'
Account = require('../models/account').default
Utils = require '../models/utils'
DatabaseStore = require './database-store'
keytar = require 'keytar'
NylasAPI = null

configAccountsKey = "nylas.accounts"
configVersionKey = "nylas.accountsVersion"
configTokensKey = "nylas.accountTokens"
keytarServiceName = 'Nylas'

###
Public: The AccountStore listens to changes to the available accounts in
the database and exposes the currently active Account via {::current}

Section: Stores
###
class AccountStore extends NylasStore

  constructor: ->
    @_loadAccounts()
    @listenTo Actions.removeAccount, @_onRemoveAccount
    @listenTo Actions.updateAccount, @_onUpdateAccount
    @listenTo Actions.reorderAccount, @_onReorderAccount

    if NylasEnv.isWorkWindow() and ['staging', 'production'].includes(NylasEnv.config.get('env'))
      setTimeout( =>
        @refreshHealthOfAccounts(@_accounts.map((a) -> a.id))
      , 2000)

    NylasEnv.config.onDidChange configVersionKey, (change) =>
      # If we already have this version of the accounts config, it means we
      # are the ones who saved the change, and we don't need to reload.
      return if @_version / 1 is change.newValue / 1
      oldAccountIds = _.pluck(@_accounts, 'id')
      @_loadAccounts()
      newAccountIds = _.pluck(@_accounts, 'id')
      newAccountIds = _.difference(newAccountIds, oldAccountIds)

      if newAccountIds.length > 0
        newId = newAccountIds[0]
        CategoryStore = require './category-store'
        CategoryStore.whenCategoriesReady(newId).then =>
          # TODO this Action is a hack, get rid of it in sidebar refactor
          Actions.setCollapsedSidebarItem('Inbox', false)
          Actions.focusDefaultMailboxPerspectiveForAccounts([newAccountIds[0]])

  _loadAccounts: =>
    try
      @_caches = {}
      @_tokens = {}
      @_version = NylasEnv.config.get(configVersionKey) || 0

      @_accounts = []
      for json in NylasEnv.config.get(configAccountsKey) || []
        @_accounts.push((new Account).fromJSON(json))

      # Run a few checks on account consistency. We want to display useful error
      # messages and these can result in very strange exceptions downstream otherwise.
      @_enforceAccountsValidity()

      oldTokens = NylasEnv.config.get(configTokensKey)
      if oldTokens
        # Load tokens using the old config method and save them into the keychain
        @_tokens = oldTokens
        for key, val of oldTokens
          account = @accountForId(key)
          continue unless account
          keytar.replacePassword(keytarServiceName, account.emailAddress, val)
      else
        # Load tokens using the new keytar method
        @_tokens = {}
        for account in @_accounts
          @_tokens[account.id] = keytar.getPassword(keytarServiceName, account.emailAddress)

    catch error
      NylasEnv.reportError(error)

    @_trigger()

  _enforceAccountsValidity: =>
    seenIds = {}
    seenEmails = {}
    message = null

    @_accounts = @_accounts.filter (account) =>
      if not account.emailAddress
        message = "Assertion failure: One of the accounts in config.json did not have an emailAddress, and was removed. You should re-link the account."
        return false
      if seenIds[account.id]
        message = "Assertion failure: Two of the accounts in config.json had the same ID and one was removed. Please give each account a separate ID."
        return false
      if seenEmails[account.emailAddress]
        message = "Assertion failure: Two of the accounts in config.json had the same email address and one was removed."
        return false

      seenIds[account.id] = true
      seenEmails[account.emailAddress] = true
      return true

    if message and NylasEnv.isMainWindow()
      NylasEnv.showErrorDialog("N1 was unable to load your account preferences.\n\n#{message}");

  _trigger: ->
    for account in @_accounts
      if not account?.id
        err = new Error("An invalid account was added to `this._accounts`")
        NylasEnv.reportError(err)
        @_accounts = _.compact(@_accounts)
    @trigger()

  _save: =>
    @_version += 1
    NylasEnv.config.set(configTokensKey, null)
    NylasEnv.config.set(configAccountsKey, @_accounts)
    NylasEnv.config.set(configVersionKey, @_version)
    @_trigger()

  # Inbound Events

  _onUpdateAccount: (id, updated) =>
    idx = _.findIndex @_accounts, (a) -> a.id is id
    account = @_accounts[idx]
    return unless account
    account = _.extend(account, updated)
    @_caches = {}
    @_accounts[idx] = account
    @_save()

  _onRemoveAccount: (id) =>
    account = _.findWhere(@_accounts, {id})
    return unless account
    keytar.deletePassword(keytarServiceName, account.emailAddress)

    @_caches = {}

    remainingAccounts = _.without(@_accounts, account)
    if remainingAccounts.length > 0
      Actions.setCollapsedSidebarItem('Inbox', true)
      Actions.focusDefaultMailboxPerspectiveForAccounts(remainingAccounts)

    @_accounts = remainingAccounts
    @_save()

    if remainingAccounts.length is 0
      ipc = require('electron').ipcRenderer
      ipc.send('command', 'application:relaunch-to-initial-windows', {
        resetDatabase: true,
      })

  _onReorderAccount: (id, newIdx) =>
    existingIdx = _.findIndex @_accounts, (a) -> a.id is id
    return if existingIdx is -1
    account = @_accounts[existingIdx]
    @_caches = {}
    @_accounts.splice(existingIdx, 1)
    @_accounts.splice(newIdx, 0, account)
    @_save()

  addAccountFromJSON: (json) =>
    if not json.email_address or not json.provider
      console.error("Returned account data is invalid", json)
      console.log JSON.stringify(json)
      throw new Error("Returned account data is invalid")

    @_loadAccounts()

    @_tokens[json.id] = json.auth_token
    keytar.replacePassword(keytarServiceName, json.email_address, json.auth_token)

    existingIdx = _.findIndex @_accounts, (a) ->
      a.id is json.id or a.emailAddress is json.email_address

    if existingIdx is -1
      account = (new Account).fromJSON(json)
      @_accounts.push(account)
    else
      account = @_accounts[existingIdx]
      account.fromJSON(json)

    @_save()

  refreshHealthOfAccounts: (accountIds) =>
    NylasAPI ?= require '../nylas-api'
    Promise.all(accountIds.map (accountId) =>
      return NylasAPI.makeRequest({
        path: '/account',
        accountId: accountId,
      }).then (json) =>
        existing = @accountForId(accountId)
        return unless existing # user may have deleted
        existing.fromJSON(json)
    ).finally =>
      @_caches = {}
      @_save()

  # Exposed Data

  # Private: Helper which caches the results of getter functions often needed
  # in the middle of React render cycles. (Performance critical!)

  _cachedGetter: (key, fn) ->
    @_caches[key] ?= fn()
    @_caches[key]

  # Public: Returns an {Array} of {Account} objects
  accounts: =>
    @_accounts

  accountsForItems: (items) =>
    accounts = {}
    items.forEach ({accountId}) =>
      accounts[accountId] ?= @accountForId(accountId)
    _.values(accounts)

  accountForItems: (items) =>
    accounts = @accountsForItems(items)
    return null if accounts.length > 1
    return accounts[0]

  # Public: Returns the {Account} for the given email address, or null.
  accountForEmail: (email) =>
    for account in @accounts()
      if Utils.emailIsEquivalent(email, account.emailAddress)
        return account
    for alias in @aliases()
      if Utils.emailIsEquivalent(email, alias.email)
        return @accountForId(alias.accountId)
    return null

  # Public: Returns the {Account} for the given account id, or null.
  accountForId: (id) =>
    @_cachedGetter "accountForId:#{id}", => _.findWhere(@_accounts, {id})

  aliases: =>
    @_cachedGetter "aliases", =>
      aliases = []
      for acc in @_accounts
        aliases.push(acc.me())
        for alias in acc.aliases
          aliasContact = acc.meUsingAlias(alias)
          aliasContact.isAlias = true
          aliases.push(aliasContact)
      return aliases

  aliasesFor: (accountsOrIds) =>
    ids = accountsOrIds.map (accOrId) ->
      if accOrId instanceof Account then accOrId.id else accOrId
    @aliases().filter((contact) -> contact.accountId in ids)

  # Public: Returns the currently active {Account}.
  current: =>
    throw new Error("AccountStore.current() has been deprecated.")

  # Private: This method is going away soon, do not rely on it.
  #
  tokenForAccountId: (id) =>
    @_tokens[id]

  # Private: Load fake data from a directory for taking nice screenshots
  #
  _importFakeData: (dir) =>
    fs = require 'fs-plus'
    path = require 'path'
    Message = require('../models/message').default
    Account = require('../models/account').default
    Thread = require('../models/thread').default
    Label = require '../models/label'

    @_caches = {}

    labels = {}
    threads = []
    messages = []

    account = @accountForEmail('nora@nylas.com')
    unless account
      account = new Account()
      account.serverId = account.clientId
      account.emailAddress = "nora@nylas.com"
      account.organizationUnit = 'label'
      account.label = "Nora's Email"
      account.aliases = []
      account.name = "Nora"
      account.provider = "gmail"
      @_accounts.push(account)
      @_tokens[account.id] = 'nope'

    filenames = fs.readdirSync(path.join(dir, 'threads'))
    for filename in filenames
      threadJSON = fs.readFileSync(path.join(dir, 'threads', filename))
      threadMessages = JSON.parse(threadJSON).map (j) -> (new Message).fromJSON(j)
      threadLabels = []
      threadParticipants = []
      threadAttachment = false
      threadUnread = false

      for m in threadMessages
        m.accountId = account.id
        threadParticipants = threadParticipants.concat(m.participants())
        threadAttachment ||= m.files.length > 0
        threadUnread ||= m.unread

      threadParticipants = _.uniq threadParticipants, (p) -> p.email
      threadLabels = _.uniq threadLabels, (l) -> l.id

      lastMsg = _.last(threadMessages)
      thread = new Thread(
        accountId: account.id
        serverId: lastMsg.threadId
        clientId: lastMsg.threadId
        subject: lastMsg.subject
        lastMessageReceivedTimestamp: lastMsg.date
        hasAttachment: threadAttachment
        labels: threadLabels
        participants: threadParticipants
        unread: threadUnread
        snippet: lastMsg.snippet
        starred: lastMsg.starred
      )
      messages = messages.concat(threadMessages)
      threads.push(thread)

    downloadsDir = path.join(dir, 'downloads')
    if fs.existsSync(downloadsDir)
      for filename in fs.readdirSync(downloadsDir)
        fs.copySync(path.join(downloadsDir, filename), path.join(NylasEnv.getConfigDirPath(), 'downloads', filename))

    DatabaseStore.inTransaction (t) =>
      Promise.all([
        t.persistModel(account),
        t.persistModels(_.values(labels)),
        t.persistModels(messages),
        t.persistModels(threads)
      ])
    .then =>
      Actions.focusDefaultMailboxPerspectiveForAccounts([account.id])
    .then -> new Promise (resolve, reject) -> setTimeout(resolve, 1000)

module.exports = new AccountStore()
