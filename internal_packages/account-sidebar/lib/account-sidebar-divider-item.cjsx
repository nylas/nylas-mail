React = require 'react'

{Actions} = require "nylas-exports"

class AccountSidebarDividerItem extends React.Component
  displayName: 'AccountSidebarDividerItem'

  render: =>
    <div className="item item-divider">{@props.label}</div>


module.exports = AccountSidebarDividerItem
