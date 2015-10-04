React = require "react"
AccountSwitcher = require "./account-switcher"
AccountSidebar = require "./account-sidebar"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    ComponentRegistry.register AccountSwitcher,
      location: WorkspaceStore.Location.RootSidebar

    ComponentRegistry.register AccountSidebar,
      location: WorkspaceStore.Location.RootSidebar

  deactivate: (@state) ->
    ComponentRegistry.unregister(AccountSwitcher)
    ComponentRegistry.unregister(AccountSidebar)
