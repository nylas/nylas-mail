React = require "react"
Notifications = require "./notifications"
NotificationsStickyBar = require "./notifications-sticky-bar"
{ComponentRegistry} = require("inbox-exports")

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    ComponentRegistry.register
      view: Notifications
      name: 'Notifications'
      role: 'ThreadList:Center'

    ComponentRegistry.register
      view: NotificationsStickyBar
      name: 'NotificationsStickyBar'
      role: 'ThreadList:Top'

  deactivate: ->
    ComponentRegistry.unregister('NotificationsStickyBar')
    ComponentRegistry.unregister('Notifications')

  serialize: -> @state
