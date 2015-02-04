React = require 'react'

{Actions} = require "inbox-exports"

module.exports =
AccountSidebarDividerItem = React.createClass
  render: ->
    <div className="item item-divider">{@props.label}</div>
