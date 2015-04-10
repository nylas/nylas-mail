React = require "react"
Notifications = require "./notifications"
NotificationsStickyBar = require "./notifications-sticky-bar"
{ComponentRegistry, WorkspaceStore} = require("inbox-exports")

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    ComponentRegistry.register
      view: Notifications
      name: 'Notifications'
      location: WorkspaceStore.Location.RootSidebar

    ComponentRegistry.register
      view: NotificationsStickyBar
      name: 'NotificationsStickyBar'
      location: WorkspaceStore.Sheet.Global.Header

  deactivate: ->
    ComponentRegistry.unregister('NotificationsStickyBar')
    ComponentRegistry.unregister('Notifications')

  serialize: -> @state
