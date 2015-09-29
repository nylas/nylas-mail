Actions = require '../actions'
Account = require '../models/account'
Utils = require '../models/utils'
DatabaseStore = require './database-store'
_ = require 'underscore'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

saveObjectsKey = "nylas.accounts"
saveTokensKey = "nylas.accountTokens"
saveIndexKey = "nylas.currentAccountIndex"

###
Public: The AccountStore listens to changes to the available accounts in
the database and exposes the currently active Account via {::current}

Section: Stores
###
class AccountStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_load()
    @listenTo Actions.selectAccountId, @onSelectAccountId
    atom.config.observe saveTokensKey, (updatedTokens) =>
      return if _.isEqual(updatedTokens, @_tokens)
      newAccountIds = _.keys(_.omit(updatedTokens, _.keys(@_tokens)))
      if newAccountIds.length > 0
        Actions.selectAccountId(newAccountIds[0])
      @_load()

  _load: =>
    @_accounts = []
    for json in atom.config.get(saveObjectsKey) || []
      @_accounts.push((new Account).fromJSON(json))

    index = atom.config.get(saveIndexKey) || 0
    @_index = Math.min(@_accounts.length - 1, Math.max(0, index))

    @_tokens = atom.config.get(saveTokensKey) || {}
    @trigger()

  _save: =>
    atom.config.set(saveObjectsKey, @_accounts)
    atom.config.set(saveIndexKey, @_index)
    atom.config.set(saveTokensKey, @_tokens)
    atom.config.save()

  # Inbound Events

  onSelectAccountId: (id) =>
    idx = _.findIndex @_accounts, (a) -> a.id is id
    return if idx is -1
    atom.config.set(saveIndexKey, idx)
    @_index = idx
    @trigger()

  removeAccountId: (id) =>
    idx = _.findIndex @_accounts, (a) -> a.id is id
    return if idx is -1

    delete @_tokens[id]
    @_accounts.splice(idx, 1)
    @_save()

    if @_accounts.length is 0
      ipc = require('ipc')
      ipc.send('command', 'application:reset-config-and-relaunch')
    else
      if @_index is idx
        Actions.selectAccountId(@_accounts[0].id)
      @trigger()

  addAccountFromJSON: (json) =>
    return if @_tokens[json.id]
    @_tokens[json.id] = json.auth_token
    @_accounts.push((new Account).fromJSON(json))
    @_save()
    @trigger()

  # Exposed Data

  # Public: Returns an {Array} of {Account} objects
  items: =>
    @_accounts

  # Public: Returns the {Account} for the given email address, or null.
  itemWithEmailAddress: (email) =>
    _.find @_accounts, (account) ->
      Utils.emailIsEquivalent(email, account.emailAddress)

  # Public: Returns the currently active {Account}.
  current: =>
    @_accounts[@_index] || null

  # Private: This method is going away soon, do not rely on it.
  #
  tokenForAccountId: (id) =>
    @_tokens[id]

module.exports = new AccountStore()
