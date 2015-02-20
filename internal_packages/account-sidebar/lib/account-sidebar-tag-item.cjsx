React = require 'react'
{Actions} = require("inbox-exports")

module.exports =
AccountSidebarTagItem = React.createClass
  render: ->
    unread = if @props.tag.unreadCount > 0 then <div className="unread">{@props.tag.unreadCount}</div> else []
    className = "item item-tag" + if @props.select then " selected" else ""
    <div className={className} onClick={@_onClick} id={@props.tag.id}>
      {unread}
      <span className="name"> {@props.tag.name}</span>
    </div>

  _onClick: (event) ->
    event.preventDefault()
    Actions.selectTagId(@props.tag.id)
