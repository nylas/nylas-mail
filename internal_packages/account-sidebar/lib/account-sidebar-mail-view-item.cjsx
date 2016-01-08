React = require 'react'
classNames = require 'classnames'
{Actions,
 Utils,
 WorkspaceStore,
 AccountStore,
 FocusedPerspectiveStore,
 CategoryStore} = require 'nylas-exports'
{RetinaImg, DropZone} = require 'nylas-component-kit'

class AccountSidebarMailViewItem extends React.Component
  @displayName: 'AccountSidebarMailViewItem'

  @propTypes:
    select: React.PropTypes.bool
    item: React.PropTypes.object.isRequired
    perspective: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = {}

  shouldComponentUpdate: (nextProps, nextState) =>
    !Utils.isEqualReact(@props, nextProps) or !Utils.isEqualReact(@state, nextState)

  render: =>
    isDeleted = @props.perspective?.category?.isDeleted is true

    containerClass = classNames
      'item': true
      'selected': @props.select
      'dropping': @state.isDropping
      'deleted': isDeleted

    <DropZone className={containerClass}
         onClick={@_onClick}
         id={@props.perspective.id}
         shouldAcceptDrop={@_shouldAcceptDrop}
         onDragStateChange={ ({isDropping}) => @setState({isDropping}) }
         onDrop={@_onDrop}>
      {@_renderUnreadCount()}
      <div className="icon">{@_renderIcon()}</div>
      <div className="name">{@props.item.name}</div>
    </DropZone>

  _renderUnreadCount: =>
    return false unless @props.item.unreadCount
    className = 'item-count-box '
    className += @props.perspective.category?.name
    <div className={className}>{@props.item.unreadCount}</div>

  _renderIcon: ->
    <RetinaImg name={@props.perspective.iconName} fallback={'folder.png'} mode={RetinaImg.Mode.ContentIsMask} />

  _shouldAcceptDrop: (e) =>
    return false if @props.perspective.isEqual(FocusedPerspectiveStore.current())
    return false unless @props.perspective.canApplyToThreads()
    'nylas-thread-ids' in e.dataTransfer.types

  _onDrop: (e) =>
    jsonString = e.dataTransfer.getData('nylas-thread-ids')
    try
      ids = JSON.parse(jsonString)
    catch err
      console.error("AccountSidebarMailViewItem onDrop: JSON parse #{err}")
    return unless ids

    @props.perspective.applyToThreads(ids)

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.focusMailboxPerspective(@props.perspective)

module.exports = AccountSidebarMailViewItem
