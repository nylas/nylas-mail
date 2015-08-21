React = require "react"
AccountSidebar = require "./account-sidebar"
AccountSwitcher = require "./account-switcher"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    ComponentRegistry.register AccountSwitcher,
      location: WorkspaceStore.Location.RootSwitcher

    ComponentRegistry.register AccountSidebar,
      location: WorkspaceStore.Location.RootSidebar

  deactivate: (@state) ->
    ComponentRegistry.unregister(AccountSidebar)
