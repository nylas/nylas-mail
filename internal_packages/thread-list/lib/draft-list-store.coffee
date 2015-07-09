Reflux = require 'reflux'
_ = require 'underscore'
{Message,
 Actions,
 DatabaseStore,
 FocusedContentStore,
 DestroyDraftTask,
 DatabaseView} = require 'nylas-exports'

module.exports =
DraftListStore = Reflux.createStore
  init: ->
    @listenTo DatabaseStore, @_onDataChanged
    @listenTo Actions.deleteSelection, @_onDeleteSelection

    @_view = new DatabaseView Message,
      matchers: [Message.attributes.draft.equal(true)],
      includes: [Message.attributes.body]
      orders: [Message.attributes.date.descending()]

    @listenTo @_view, => @trigger({})

  view: ->
    @_view

  _onDataChanged: (change) ->
    return unless change.objectClass is Message.name
    containsDraft = _.some(change.objects, (msg) -> msg.draft)
    return unless containsDraft
    @_view.invalidate()

  _onDeleteSelection: ->
    selected = @_view.selection.items()

    for item in selected
      DatabaseStore.localIdForModel(item).then (localId) =>
        Actions.queueTask(new DestroyDraftTask(localId))
        # if thread.id is focusedId
        #   Actions.setFocus(collection: 'thread', item: null)
        # if thread.id is keyboardId
        #   Actions.setCursorPosition(collection: 'thread', item: null)

    @_view.selection.clear()
