React = require 'react'
classNames = require 'classnames'
{Actions,
 Utils,
 ThreadCountsStore,
 WorkspaceStore,
 AccountStore,
 FocusedMailViewStore,
 ChangeLabelsTask,
 ChangeFolderTask,
 CategoryStore} = require 'nylas-exports'
{RetinaImg, DropZone} = require 'nylas-component-kit'

class AccountSidebarMailViewItem extends React.Component
  @displayName: 'AccountSidebarMailViewItem'

  @propTypes:
    select: React.PropTypes.bool
    item: React.PropTypes.object.isRequired
    itemUnreadCount: React.PropTypes.number
    mailView: React.PropTypes.object.isRequired

  constructor: (@props) ->
    @state = {}

  shouldComponentUpdate: (nextProps, nextState) =>
    !Utils.isEqualReact(@props, nextProps) or !Utils.isEqualReact(@state, nextState)

  render: =>
    containerClass = classNames
      'item': true
      'selected': @props.select
      'dropping': @state.isDropping

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
    return false if @props.itemUnreadCount is 0
    className = 'item-count-box '
    className += @props.mailView.category?.name
    <div className={className}>{@props.itemUnreadCount}</div>

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
