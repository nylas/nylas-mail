React = require "react"
ActivitySidebar = require "./activity-sidebar"
NotificationStore = require './notifications-store'
NotificationsStickyBar = require "./notifications-sticky-bar"
{ComponentRegistry, WorkspaceStore} = require("nylas-exports")

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    ComponentRegistry.register ActivitySidebar,
      location: WorkspaceStore.Location.RootSidebar

    ComponentRegistry.register NotificationsStickyBar,
      location: WorkspaceStore.Sheet.Global.Header

  deactivate: ->
    ComponentRegistry.unregister(ActivitySidebar)
    ComponentRegistry.unregister(NotificationsStickyBar)

  serialize: -> @state
