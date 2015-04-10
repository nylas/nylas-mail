React = require 'react'
{Actions, Utils, WorkspaceStore} = require 'inbox-exports'
{RetinaImg} = require 'ui-components'

module.exports =
AccountSidebarTagItem = React.createClass
  displayName: 'AccountSidebarTagItem'

  shouldComponentUpdate: (nextProps) ->
    @props?.item.id isnt nextProps.item.id or
    @props?.item.unreadCount isnt nextProps.item.unreadCount or
    @props?.select isnt nextProps.select

  render: ->
    unread = []
    if @props.item.unreadCount > 0
      unread = <div className="unread item-count-box">{@props.item.unreadCount}</div>

    classSet =  React.addons.classSet
      'item': true
      'selected': @props.select

    <div className={classSet} onClick={@_onClick} id={@props.item.id}>
      <RetinaImg name={"#{@props.item.id}.png"} fallback={'folder.png'} colorfill={@props.select} />
      <span className="name"> {@props.item.name}</span>
      {unread}
    </div>

  _onClick: (event) ->
    event.preventDefault()
    Actions.selectRootSheet(WorkspaceStore.Sheet.Threads)
    Actions.focusTag(@props.item)
