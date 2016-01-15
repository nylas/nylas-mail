_ = require 'underscore'
{Actions,
 WorkspaceStore} = require 'nylas-exports'

module.exports =
class MultiselectListInteractionHandler
  constructor: (@props) ->
    {@onFocusItemItem, @onSetCursorPosition} = @props

  cssClass: ->
    'handler-list'

  shouldShowFocus: ->
    false

  shouldShowCheckmarks: ->
    true

  shouldShowKeyboardCursor: ->
    true

  onClick: (item) ->
    @onFocusItem(item)

  onMetaClick: (item) ->
    @props.dataSource.selection.toggle(item)
    @onSetCursorPosition(item)

  onShiftClick: (item) ->
    @props.dataSource.selection.expandTo(item)
    @onSetCursorPosition(item)

  onEnter: ->
    keyboardCursorId = @props.keyboardCursorId
    if keyboardCursorId
      item = @props.dataSource.getById(keyboardCursorId)
      @onFocusItem(item)

  onSelect: ->
    {id} = @_keyboardContext()
    return unless id
    @props.dataSource.selection.toggle(@props.dataSource.getById(id))

  onShift: (delta, options = {}) ->
    {id, action} = @_keyboardContext()

    current = @props.dataSource.getById(id)
    index = @props.dataSource.indexOfId(id)
    index = Math.max(0, Math.min(index + delta, @props.dataSource.count() - 1))
    next = @props.dataSource.get(index)

    action(next)
    if options.select
      @props.dataSource.selection.walk({current, next})

  _keyboardContext: ->
    if WorkspaceStore.topSheet().root
      {id: @props.keyboardCursorId, action: @onSetCursorPosition}
    else
      {id: @props.focusedId, action: @onFocusItem}
