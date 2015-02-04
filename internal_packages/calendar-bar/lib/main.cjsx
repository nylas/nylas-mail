React = require "react"
CalendarBar = require "./calendar-bar"

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state) ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "calendar-bar")
      @item.setAttribute("class", "calendar-bar")

      React.render(<CalendarBar /> , @item)

      atom.workspace.addRow(@item)

  deactivate: ->
    React.unmountComponentAtNode(@item)
    @item.remove()
    @item = null

  serialize: -> @state
