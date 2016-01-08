NylasStore = require 'nylas-store'
Reflux = require 'reflux'
_ = require 'underscore'
{Message,
 Actions,
 DatabaseStore,
 AccountStore,
 FocusedContentStore,
 DestroyDraftTask,
 DatabaseView} = require 'nylas-exports'

class DraftListStore extends NylasStore
  constructor: ->
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo AccountStore, @_onAccountChanged

    # It's important to listen to sendDraftSuccess because the
    # _onDataChanged method will ignore our newly created draft because it
    # has its draft bit set to false (since it's now a message)!
    @listenTo Actions.sendDraftSuccess, => @_view.invalidate()
    @_createView()

  view: =>
    @_view

  _createView: =>
    account = FocusedMailViewStore.mailView()?.account

    if @unlisten
      @unlisten()
      @_view = null

    matchers = [
      Message.attributes.draft.equal(true)
    ]
    if account?
      matchers.push(Message.attributes.accountId.equal(account.id))

    @_view = new DatabaseView Message,
      matchers: matchers,
      includes: [Message.attributes.body]
      orders: [Message.attributes.date.descending()]

    @unlisten = @_view.listen => @trigger({})

  _onAccountChanged: =>
    @_createView()

  _onDataChanged: (change) =>
    return unless change.objectClass is Message.name
    return unless @_view
    @_view.invalidate({change: change, shallow: true})

module.exports = new DraftListStore()
