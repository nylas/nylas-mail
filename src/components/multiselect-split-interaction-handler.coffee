_ = require 'underscore'
{Actions,
 WorkspaceStore} = require 'nylas-exports'

module.exports =
class MultiselectSplitInteractionHandler
  constructor: (@props) ->
    {@onFocusItem, @onSetCursorPosition} = @props

  cssClass: =>
    'handler-split'

  shouldShowFocus: =>
    true

  shouldShowCheckmarks: =>
    false

  shouldShowKeyboardCursor: =>
    @props.dataSource.selection.count() > 1

  onClick: (item) =>
    @onFocusItem(item)
    @props.dataSource.selection.clear()
    @_checkSelectionAndFocusConsistency()

  onMetaClick: (item) =>
    @_turnFocusIntoSelection()
    @props.dataSource.selection.toggle(item)
    @_checkSelectionAndFocusConsistency()

  onShiftClick: (item) =>
    @_turnFocusIntoSelection()
    @props.dataSource.selection.expandTo(item)
    @_checkSelectionAndFocusConsistency()

  onEnter: =>

  onSelect: =>
    @_checkSelectionAndFocusConsistency()

  onShift: (delta, options) =>
    if options.select
      @_turnFocusIntoSelection()

    if @props.dataSource.selection.count() > 0
      selection = @props.dataSource.selection
      keyboardId = @props.keyboardCursorId
      id = keyboardId ? @props.dataSource.selection.top().id
      action = @onSetCursorPosition
    else
      id = @props.focusedId
      action = @onFocusItem

    current = @props.dataSource.getById(id)
    index = @props.dataSource.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @props.dataSource.count() - 1))
    next = @props.dataSource.get(index)

    action(next)
    if options.select
      @props.dataSource.selection.walk({current, next})

    @_checkSelectionAndFocusConsistency()

  _turnFocusIntoSelection: =>
    focused = @props.focused
    @onFocusItem(null)
    @props.dataSource.selection.add(focused)

  _checkSelectionAndFocusConsistency: =>
    focused = @props.focused
    selection = @props.dataSource.selection

    if focused and selection.count() > 0
      @props.dataSource.selection.add(focused)
      @onFocusItem(null)

    if selection.count() is 1 and !focused
      @onFocusItem(selection.items()[0])
      @props.dataSource.selection.clear()
