React = require 'react'
classNames = require 'classnames'
{Actions, Utils, WorkspaceStore} = require 'nylas-exports'
{RetinaImg} = require 'nylas-component-kit'

class AccountSidebarTagItem extends React.Component
  @displayName: 'AccountSidebarTagItem'

  shouldComponentUpdate: (nextProps) =>
    @props?.item.id isnt nextProps.item.id or
    @props?.item.unreadCount isnt nextProps.item.unreadCount or
    @props?.select isnt nextProps.select

  render: =>
    unread = []
    if @props.item.unreadCount > 0
      unread = <div className="unread item-count-box">{@props.item.unreadCount}</div>

    coontainerClass = classNames
      'item': true
      'selected': @props.select

    <div className={coontainerClass} onClick={@_onClick} id={@props.item.id}>
      {unread}
      <RetinaImg name={"#{@props.item.id}.png"} fallback={'folder.png'} mode={RetinaImg.Mode.ContentIsMask} />
      <span className="name"> {@props.item.name}</span>
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.focusTag(@props.item)


module.exports = AccountSidebarTagItem
