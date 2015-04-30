React = require "react"
Notifications = require "./notifications"
NotificationsStickyBar = require "./notifications-sticky-bar"
{ComponentRegistry, WorkspaceStore} = require("inbox-exports")

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    ComponentRegistry.register Notifications,
      location: WorkspaceStore.Location.RootSidebar

    ComponentRegistry.register NotificationsStickyBar,
      location: WorkspaceStore.Sheet.Global.Header

  deactivate: ->
    ComponentRegistry.unregister('NotificationsStickyBar')
    ComponentRegistry.unregister('Notifications')

  serialize: -> @state
