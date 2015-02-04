React = require "react"
Notifications = require "./notifications"
NotificationsStickyBar = require "./notifications-sticky-bar"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "notifications-wrap")
      @item.setAttribute("class", "notifications-wrap")
      atom.workspace.addColumnItem(@item, "thread-list-column")
      React.render(<Notifications /> , @item)

    unless @stickyItem?
      @stickyItem = document.createElement("div")
      @stickyItem.setAttribute("id", "notifications-sticky-bar")
      @stickyItem.setAttribute("class", "notifications-sticky-bar")
      atom.workspace.addRow(@stickyItem)
      React.render(<NotificationsStickyBar /> , @stickyItem)

  deactivate: ->
    React.unmountComponentAtNode(@item)
    @item.remove()
    @item = null

    React.unmountComponentAtNode(@stickyItem)
    @stickyItem.remove()
    @stickyItem = null

  serialize: -> @state
