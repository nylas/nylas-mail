React = require 'react'
{FocusedContentStore, Actions} = require 'nylas-exports'
{FluxContainer} = require 'nylas-component-kit'

class FocusContainer extends React.Component
  @displayName: 'FocusContainer'
  @propTypes:
    children: React.PropTypes.element
    collection: React.PropTypes.string

  getStateFromStores: =>
    focused: FocusedContentStore.focused(@props.collection)
    focusedId: FocusedContentStore.focusedId(@props.collection)
    keyboardCursor: FocusedContentStore.keyboardCursor(@props.collection)
    keyboardCursorId: FocusedContentStore.keyboardCursorId(@props.collection)
    onFocusItem: (item) =>
      Actions.setFocus({collection: @props.collection, item: item})
    onSetCursorPosition: (item) =>
      Actions.setCursorPosition({collection: @props.collection, item: item})

  render: ->
    <FluxContainer {...@props} stores={[FocusedContentStore]} getStateFromStores={@getStateFromStores}>
      {@props.children}
    </FluxContainer>

module.exports = FocusContainer
