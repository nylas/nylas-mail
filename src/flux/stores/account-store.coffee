Actions = require '../actions'
Account = require '../models/account'
DatabaseStore = require './database-store'
_ = require 'underscore'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

saveStateKey = "nylas.current_account"

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
    @_items = []
    @_current = null
    @_accounts = []

    saveState = atom.config.get(saveStateKey)
    if saveState and _.isObject(saveState)
      savedAccount = (new Account).fromJSON(saveState)
      if savedAccount.usesLabels() or savedAccount.usesFolders()
        @_setCurrent(savedAccount)
        @_accounts = [@_current]

    @listenTo Actions.selectAccountId, @onSelectAccountId
    @listenTo DatabaseStore, @onDataChanged

    @populateItems()

  populateItems: =>
    DatabaseStore.findAll(Account).order(Account.attributes.emailAddress.descending()).then (accounts) =>
      current = _.find accounts, (a) -> a.id is @_current?.id
      current = accounts?[0] unless current

      if not _.isEqual(current, @_current) or not _.isEqual(accounts, @_accounts)
        @_setCurrent(current)
        @_accounts = accounts
        @trigger()

    .catch (err) =>
      console.warn("Request for accounts failed. #{err}", err.stack)

  _setCurrent: (current) =>
    atom.config.set(saveStateKey, current)
    @_current = current

  # Inbound Events

  onDataChanged: (change) =>
    return unless change && change.objectClass is Account.name
    @populateItems()

  onSelectAccountId: (id) =>
    return if @_current?.id is id
    @_current = _.find @_accounts, (a) -> a.id is id
    @trigger(@)

  # Exposed Data

  # Public: Returns an {Array} of {Account} objects
  items: =>
    @_accounts

  # Public: Returns the currently active {Account}.
  current: =>
    @_current

module.exports = new AccountStore()
