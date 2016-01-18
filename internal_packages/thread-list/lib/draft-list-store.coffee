NylasStore = require 'nylas-store'
Reflux = require 'reflux'
Rx = require 'rx-lite'
_ = require 'underscore'
{Message,
 Actions,
 AccountStore,
 MutableQuerySubscription,
 ObservableListDataSource,
 FocusedPerspectiveStore,
 DatabaseStore} = require 'nylas-exports'

class DraftListStore extends NylasStore
  constructor: ->
    @listenTo AccountStore, @_onAccountChanged

    @subscription = new MutableQuerySubscription(@_queryForCurrentAccount(), {asResultSet: true})
    $resultSet = Rx.Observable.fromPrivateQuerySubscription('draft-list', @subscription)

    @_view = new ObservableListDataSource $resultSet, ({start, end}) =>
      @subscription.replaceQuery(@_queryForCurrentAccount().page(start, end))

  view: =>
    @_view

  _queryForCurrentAccount: =>
    matchers = [Message.attributes.draft.equal(true)]
    account = FocusedPerspectiveStore.current().account

    if account?
      matchers.push(Message.attributes.accountId.equal(account.id))

    query = DatabaseStore.findAll(Message)
      .include(Message.attributes.body)
      .order(Message.attributes.date.descending())
      .where(matchers)
      .page(0, 1)

  _onAccountChanged: =>
    @subscription.replaceQuery(@_queryForCurrentAccount())

module.exports = new DraftListStore()
