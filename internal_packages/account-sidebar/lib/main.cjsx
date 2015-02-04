React = require "react"
AccountSidebar = require "./account-sidebar"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "account-sidebar")
      @item.setAttribute("class", "account-sidebar")

      React.render(<AccountSidebar /> , @item)

      atom.workspace.addColumnItem(@item, "left-sidebar")

  deactivate: ->
    React.unmountComponentAtNode(@item)
    @item.remove()
    @item = null

  serialize: -> @state
