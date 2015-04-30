React = require 'react'
{Actions} = require("inbox-exports")

class AccountSidebarItem extends React.Component
  @displayName: "AccountSidebarItem"

  render: =>
    className = "item " + if @props.select then " selected" else ""
    <div className={className} onClick={@_onClick} id={@props.item.id}>
      <span className="name"> {@props.item.name}</span>
    </div>

  _onClick: (event) =>
    event.preventDefault()
    Actions.selectView(@props.item.view)


module.exports = AccountSidebarItem
