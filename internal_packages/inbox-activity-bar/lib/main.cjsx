React = require 'react'
ActivityBar = require('./activity-bar')

module.exports =
  item: null

  activate: (@state={}) ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "activity-bar")
      @item.setAttribute("class", "activity-bar")

      atom.workspace.addRow(@item)

      React.render(<ActivityBar />, @item)

  deactivate: ->
    React.unmountComponentAtNode(@item)
    @item.remove()
    @item = null

  serialize: -> @state
