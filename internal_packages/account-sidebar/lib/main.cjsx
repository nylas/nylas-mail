React = require "react"
AccountSidebar = require "./account-sidebar"
{ComponentRegistry} = require "inbox-exports"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    ComponentRegistry.register
      view: AccountSidebar
      name: 'AccountSidebar'
      role: 'Root:Left'
