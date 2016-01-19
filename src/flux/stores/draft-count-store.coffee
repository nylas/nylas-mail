_ = require 'underscore'
Rx = require 'rx-lite'
NylasStore = require 'nylas-store'
Actions = require '../actions'
Message = require '../models/message'
Account = require '../models/account'
DatabaseStore = require './database-store'
AccountStore = require './account-store'
FocusedPerspectiveStore = require './focused-perspective-store'

###
Public: The DraftCountStore exposes a simple API for getting the number of
drafts in the user's account. If you plugin needs the number of drafts,
it's more efficient to observe the DraftCountStore than retrieve the value
yourself from the database.

The DraftCountStore is only available in the main window.
###

if not NylasEnv.isMainWindow() and not NylasEnv.inSpecMode() then return

class DraftCountStore extends NylasStore

  constructor: ->
    @_counts = {}
    @_total = 0
    @_disposable = Rx.Observable.fromQuery(
      DatabaseStore.findAll(Message).where([Message.attributes.draft.equal(true)])
    ).subscribe(@_onDraftsChanged)

  totalCount: ->
    @_total

  # Public: Returns the number of drafts for the given account
  count: (accountOrId)->
    return 0 unless accountOrId
    accountId = if accountOrId instanceof Account
      accountOrId.id
    else
      accountOrId
    @_counts[accountId]

  _onDraftsChanged: (drafts) =>
    @_total = 0
    @_counts = {}
    for account in AccountStore.accounts()
      @_counts[account.id] = _.where(drafts, accountId: account.id).length
      @_total += @_counts[account.id]
    @trigger()


module.exports = new DraftCountStore()
