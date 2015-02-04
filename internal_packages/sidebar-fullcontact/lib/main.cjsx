_ = require 'underscore-plus'
React = require "react"
SidebarFullContact = require "./sidebar-fullcontact.cjsx"

{ComponentRegistry} = require("inbox-exports")

module.exports =
  item: null

  activate: (@state={}) ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "sidebar-fullcontact")
      @item.setAttribute("class", "sidebar-fullcontact")

      atom.workspace.addColumnItem(@item, "message-and-composer")

      ComponentRegistry.register
        name: 'SidebarFullContact'
        view: SidebarFullContact

      React.render(<SidebarFullContact />, @item)

  deactivate: ->
    React.unmountComponentAtNode(@item)
    @item.remove()
    @item = null

  serialize: -> @state
