React = require 'react'
{Actions} = require("inbox-exports")

module.exports =
AccountSidebarTagItem = React.createClass
  render: ->
    unread = if @props.unreadCount > 0 then @props.unreadCount else ""
    className = "item item-tag" + if @props.select then " selected" else ""
    <div className={className} onClick={@_onClick} id={@props.tag.id}>
      <div className="unread"> {unread}</div>
      <span className="name"> {@props.tag.name}</span>
    </div>

  _onClick: (event) ->
    event.preventDefault()
    Actions.selectTagId(@props.tag.id)
