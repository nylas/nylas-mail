React = require 'react'

{Actions} = require "inbox-exports"

class AccountSidebarDividerItem extends React.Component
  displayName: 'AccountSidebarDividerItem'

  render: =>
    <div className="item item-divider">{@props.label}</div>


module.exports = AccountSidebarDividerItem
