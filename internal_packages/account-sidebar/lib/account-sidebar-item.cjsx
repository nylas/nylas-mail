React = require 'react'
{Actions} = require("inbox-exports")

module.exports =
AccountSidebarItem = React.createClass
  render: ->
    className = "item " + if @props.select then " selected" else ""
    <div className={className} onClick={@_onClick} id={@props.item.id}>
      <span className="name"> {@props.item.name}</span>
    </div>

  _onClick: (event) ->
    event.preventDefault()
    Actions.selectView(@props.item.view)
