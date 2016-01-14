_ = require 'underscore'
{Actions,
 WorkspaceStore,
 FocusedContentStore} = require 'nylas-exports'

module.exports =
class MultiselectSplitInteractionHandler
  constructor: (@dataSource, @collection) ->

  cssClass: ->
    'handler-split'

  shouldShowFocus: ->
    true

  shouldShowKeyboardCursor: ->
    @dataSource.selection.count() > 1

  onClick: (item) ->
    Actions.setFocus({collection: @collection, item: item, usingClick: true})
    @dataSource.selection.clear()
    @_checkSelectionAndFocusConsistency()

  onMetaClick: (item) ->
    @_turnFocusIntoSelection()
    @dataSource.selection.toggle(item)
    @_checkSelectionAndFocusConsistency()

  onShiftClick: (item) ->
    @_turnFocusIntoSelection()
    @dataSource.selection.expandTo(item)
    @_checkSelectionAndFocusConsistency()

  onEnter: ->

  onSelect: ->
    @_checkSelectionAndFocusConsistency()

  onShift: (delta, options) ->
    if options.select
      @_turnFocusIntoSelection()

    if @dataSource.selection.count() > 0
      selection = @dataSource.selection
      keyboardId = FocusedContentStore.keyboardCursorId(@collection)
      id = keyboardId ? @dataSource.selection.top().id
      action = Actions.setCursorPosition
    else
      id = FocusedContentStore.focusedId(@collection)
      action = Actions.setFocus

    current = @dataSource.getById(id)
    index = @dataSource.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @dataSource.count() - 1))
    next = @dataSource.get(index)

    action({collection: @collection, item: next})
    if options.select
      @dataSource.selection.walk({current, next})

    @_checkSelectionAndFocusConsistency()

  _turnFocusIntoSelection: ->
    focused = FocusedContentStore.focused(@collection)
    Actions.setFocus({collection: @collection, item: null})
    @dataSource.selection.add(focused)

  _checkSelectionAndFocusConsistency: ->
    focused = FocusedContentStore.focused(@collection)
    selection = @dataSource.selection

    if focused and selection.count() > 0
      @dataSource.selection.add(focused)
      Actions.setFocus({collection: @collection, item: null})

    if selection.count() is 1 and !focused
      Actions.setFocus({collection: @collection, item: selection.items()[0]})
      @dataSource.selection.clear()
