React = require "react"
AccountSidebar = require "./components/account-sidebar"
SidebarCommands = require "./sidebar-commands"
{ComponentRegistry, WorkspaceStore} = require "nylas-exports"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    ComponentRegistry.register AccountSidebar,
      location: WorkspaceStore.Location.RootSidebar
    SidebarCommands.register()

  deactivate: (@state) ->
    ComponentRegistry.unregister(AccountSidebar)
