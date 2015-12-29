_ = require 'underscore'
{Actions,
 WorkspaceStore,
 FocusedContentStore} = require 'nylas-exports'

module.exports =
class MultiselectSplitInteractionHandler
  constructor: (@dataView, @collection) ->

  cssClass: ->
    'handler-split'

  shouldShowFocus: ->
    true

  shouldShowKeyboardCursor: ->
    @dataView.selection.count() > 1

  onClick: (item) ->
    Actions.setFocus({collection: @collection, item: item, usingClick: true})
    @dataView.selection.clear()
    @_checkSelectionAndFocusConsistency()

  onMetaClick: (item) ->
    @_turnFocusIntoSelection()
    @dataView.selection.toggle(item)
    @_checkSelectionAndFocusConsistency()

  onShiftClick: (item) ->
    @_turnFocusIntoSelection()
    @dataView.selection.expandTo(item)
    @_checkSelectionAndFocusConsistency()

  onEnter: ->

  onSelect: ->
    @_checkSelectionAndFocusConsistency()

  onShift: (delta, options) ->
    if options.select
      @_turnFocusIntoSelection()

    if @dataView.selection.count() > 0
      selection = @dataView.selection
      keyboardId = FocusedContentStore.keyboardCursorId(@collection)
      id = keyboardId ? @dataView.selection.top().id
      action = Actions.setCursorPosition
    else
      id = FocusedContentStore.focusedId(@collection)
      action = Actions.setFocus

    current = @dataView.getById(id)
    index = @dataView.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @dataView.count() - 1))
    next = @dataView.get(index)

    action({collection: @collection, item: next})
    if options.select
      @dataView.selection.walk({current, next})

    @_checkSelectionAndFocusConsistency()

  _turnFocusIntoSelection: ->
    focused = FocusedContentStore.focused(@collection)
    Actions.setFocus({collection: @collection, item: null})
    @dataView.selection.add(focused)

  _checkSelectionAndFocusConsistency: ->
    focused = FocusedContentStore.focused(@collection)
    selection = @dataView.selection

    if focused and selection.count() > 0
      @dataView.selection.add(focused)
      Actions.setFocus({collection: @collection, item: null})

    if selection.count() is 1 and !focused
      Actions.setFocus({collection: @collection, item: selection.items()[0]})
      @dataView.selection.clear()
