React = require "react"
AccountSidebar = require "./components/account-sidebar"
{ComponentRegistry, WorkspaceStore} = require "mailspring-exports"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    ComponentRegistry.register AccountSidebar,
      location: WorkspaceStore.Location.RootSidebar

  deactivate: (@state) ->
    ComponentRegistry.unregister(AccountSidebar)
