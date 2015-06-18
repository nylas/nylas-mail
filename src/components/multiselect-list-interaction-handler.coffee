_ = require 'underscore'
{Actions,
 WorkspaceStore,
 FocusedContentStore} = require 'nylas-exports'

module.exports =
class MultiselectListInteractionHandler
  constructor: (@dataView, @collection) ->

  cssClass: ->
    'handler-list'

  shouldShowFocus: ->
    false

  shouldShowKeyboardCursor: ->
    true

  onClick: (item) ->
    Actions.setFocus({collection: @collection, item: item})

  onMetaClick: (item) ->
    @dataView.selection.toggle(item)
    Actions.setCursorPosition({collection: @collection, item: item})

  onShiftClick: (item) ->
    @dataView.selection.expandTo(item)
    Actions.setCursorPosition({collection: @collection, item: item})

  onEnter: ->
    keyboardCursorId = FocusedContentStore.keyboardCursorId(@collection)
    if keyboardCursorId
      item = @dataView.getById(keyboardCursorId)
      Actions.setFocus({collection: @collection, item: item})

  onSelect: ->
    {id} = @_keyboardContext()
    return unless id
    @dataView.selection.toggle(@dataView.getById(id))

  onShift: (delta, options = {}) ->
    {id, action} = @_keyboardContext()

    current = @dataView.getById(id)
    index = @dataView.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @dataView.count() - 1))
    next = @dataView.get(index)

    action({collection: @collection, item: next})
    if options.select
      @dataView.selection.walk({current, next})

  _keyboardContext: ->
    if WorkspaceStore.topSheet().root
      {id: FocusedContentStore.keyboardCursorId(@collection), action: Actions.setCursorPosition}
    else
      {id: FocusedContentStore.focusedId(@collection), action: Actions.setFocus}
