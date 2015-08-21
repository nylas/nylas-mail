Reflux = require 'reflux'
_ = require 'underscore'
{Message,
 Actions,
 DatabaseStore,
 AccountStore,
 FocusedContentStore,
 DestroyDraftTask,
 DatabaseView} = require 'nylas-exports'

module.exports =
DraftListStore = Reflux.createStore
  init: ->
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo AccountStore, @_onAccountChanged
    @listenTo Actions.deleteSelection, @_onDeleteSelection
    @_createView()

  view: ->
    @_view

  _createView: ->
    account = AccountStore.current()

    if @unlisten
      @unlisten()
      @_view = null

    return unless account

    @_view = new DatabaseView Message,
      matchers: [
        Message.attributes.accountId.equal(account.id)
        Message.attributes.draft.equal(true)
      ],
      includes: [Message.attributes.body]
      orders: [Message.attributes.date.descending()]

    @unlisten = @_view.listen => @trigger({})

  _onAccountChanged: ->
    @_createView()

  _onDataChanged: (change) ->
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft
    @_view.invalidate()

  _onDeleteSelection: ->
    selected = @_view.selection.items()

    for item in selected
      DatabaseStore.localIdForModel(item).then (localId) =>
        Actions.queueTask(new DestroyDraftTask(draftLocalId: localId))
        # if thread.id is focusedId
        #   Actions.setFocus(collection: 'thread', item: null)
        # if thread.id is keyboardId
        #   Actions.setCursorPosition(collection: 'thread', item: null)

    @_view.selection.clear()
