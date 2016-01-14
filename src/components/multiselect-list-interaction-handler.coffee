_ = require 'underscore'
{Actions,
 WorkspaceStore,
 FocusedContentStore} = require 'nylas-exports'

module.exports =
class MultiselectListInteractionHandler
  constructor: (@dataSource, @collection) ->

  cssClass: ->
    'handler-list'

  shouldShowFocus: ->
    false

  shouldShowKeyboardCursor: ->
    true

  onClick: (item) ->
    Actions.setFocus({collection: @collection, item: item})

  onMetaClick: (item) ->
    @dataSource.selection.toggle(item)
    Actions.setCursorPosition({collection: @collection, item: item})

  onShiftClick: (item) ->
    @dataSource.selection.expandTo(item)
    Actions.setCursorPosition({collection: @collection, item: item})

  onEnter: ->
    keyboardCursorId = FocusedContentStore.keyboardCursorId(@collection)
    if keyboardCursorId
      item = @dataSource.getById(keyboardCursorId)
      Actions.setFocus({collection: @collection, item: item})

  onSelect: ->
    {id} = @_keyboardContext()
    return unless id
    @dataSource.selection.toggle(@dataSource.getById(id))

  onShift: (delta, options = {}) ->
    {id, action} = @_keyboardContext()

    current = @dataSource.getById(id)
    index = @dataSource.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @dataSource.count() - 1))
    next = @dataSource.get(index)

    action({collection: @collection, item: next})
    if options.select
      @dataSource.selection.walk({current, next})

  _keyboardContext: ->
    if WorkspaceStore.topSheet().root
      {id: FocusedContentStore.keyboardCursorId(@collection), action: Actions.setCursorPosition}
    else
      {id: FocusedContentStore.focusedId(@collection), action: Actions.setFocus}
