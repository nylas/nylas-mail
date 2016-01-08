React = require 'react'
classNames = require 'classnames'
{Actions,
 Utils,
 WorkspaceStore,
 AccountStore,
 FocusedMailViewStore,
 CategoryStore} = require 'nylas-exports'
{RetinaImg, DropZone} = require 'nylas-component-kit'

class AccountSidebarMailViewItem extends React.Component
  @displayName: 'AccountSidebarMailViewItem'

  @propTypes:
    select: React.PropTypes.bool
    item: React.PropTypes.object.isRequired
    mailView: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = {}

  shouldComponentUpdate: (nextProps, nextState) =>
    !Utils.isEqualReact(@props, nextProps) or !Utils.isEqualReact(@state, nextState)

  render: =>
    isDeleted = @props.mailView?.category?.isDeleted is true

    containerClass = classNames
      'item': true
      'selected': @props.select
      'dropping': @state.isDropping
      'deleted': isDeleted

    <DropZone className={containerClass}
         onClick={@_onClick}
         id={@props.mailView.id}
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
    className += @props.mailView.category?.name
    <div className={className}>{@props.item.unreadCount}</div>

  _renderIcon: ->
    <RetinaImg name={@props.mailView.iconName} fallback={'folder.png'} mode={RetinaImg.Mode.ContentIsMask} />

  _shouldAcceptDrop: (e) =>
    return false if @props.mailView.isEqual(FocusedMailViewStore.mailView())
    return false unless @props.mailView.canApplyToThreads()
    'nylas-thread-ids' in e.dataTransfer.types

  _onDrop: (e) =>
    jsonString = e.dataTransfer.getData('nylas-thread-ids')
    try
      ids = JSON.parse(jsonString)
    catch err
      console.error("AccountSidebarMailViewItem onDrop: JSON parse #{err}")
    return unless ids

    @props.mailView.applyToThreads(ids)

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.focusMailView(@props.mailView)

module.exports = AccountSidebarMailViewItem
