NylasStore = require 'nylas-store'
Rx = require 'rx-lite'
_ = require 'underscore'
{Message,
 MutableQuerySubscription,
 ObservableListDataSource,
 FocusedPerspectiveStore,
 DatabaseStore} = require 'nylas-exports'
{ListTabular} = require 'nylas-component-kit'

class DraftListStore extends NylasStore
  constructor: ->
    @listenTo FocusedPerspectiveStore, @_onPerspectiveChanged
    @_createListDataSource()

  dataSource: =>
    @_dataSource

  # Inbound Events

  _onPerspectiveChanged: =>
    @_createListDataSource()

  # Internal

  _createListDataSource: =>
    mailboxPerspective = FocusedPerspectiveStore.current()

    if mailboxPerspective.drafts
      query = DatabaseStore.findAll(Message)
        .include(Message.attributes.body)
        .order(Message.attributes.date.descending())
        .where(draft: true, accountId: mailboxPerspective.accountIds)
        .page(0, 1)

      subscription = new MutableQuerySubscription(query, {asResultSet: true})
      $resultSet = Rx.Observable.fromPrivateQuerySubscription('draft-list', subscription)
      @_dataSource = new ObservableListDataSource($resultSet, subscription.replaceRange)
    else
      @_dataSource = new ListTabular.DataSource.Empty()

    @trigger(@)

module.exports = new DraftListStore()
