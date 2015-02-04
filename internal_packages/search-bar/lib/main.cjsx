path = require 'path'
require 'coffee-react/register'
React = require 'react'
{Actions} = require 'inbox-exports'
SearchBar = require './search-bar'
SearchSettingsBar = require './search-settings-bar'

module.exports =
  configDefaults:
    showOnRightSide: false

  # The top-level React component itself
  item: null

  activate: (@state) ->
    @state.attached ?= true
    @_createView() if @state.attached

  deactivate: ->
    React.unmountComponentAtNode(@container)
    @container.remove()

  serialize: ->
    ""

  _createView: ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "search-bar")
      @item.setAttribute("class", "search-bar")
      atom.workspace.addColumnItem(@item, 'thread-list-column')
      React.render(<SearchBar /> , @item)
    @item
