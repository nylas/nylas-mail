React = require 'react'

{Actions} = require "inbox-exports"

module.exports =
AccountSidebarDividerItem = React.createClass
  displayName: 'AccountSidebarDividerItem'

  render: ->
    <div className="item item-divider">{@props.label}</div>
