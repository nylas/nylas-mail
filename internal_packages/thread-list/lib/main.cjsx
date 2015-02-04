_ = require 'underscore-plus'
React = require "react"

{ComponentRegistry} = require "inbox-exports"

ThreadListNarrow = require "./thread-list-narrow"
ThreadListTabular = require "./thread-list-tabular"

Participants = React.createClass({render: -> <div></div>})

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    unless @item?
      @item = document.createElement("div")
      @item.setAttribute("id", "thread-list")
      @item.setAttribute("class", "thread-list")

      atom.workspace.addColumnItem(@item, "thread-list-column")

      @narrow = @_isNarrow()
      window.addEventListener 'resize', _.bind(@_onWindowResize, @)

      @_render()

      Participants = ComponentRegistry.findViewByName("Participants")
      @_registryUnlistener = ComponentRegistry.listen (event) =>
        Participants = ComponentRegistry.findViewByName("Participants")
        @_render()

  deactivate: ->
    React.unmountComponentAtNode(@item)
    window.removeEventListener 'resize', _.bind(@_onWindowResize, @)
    @_registryUnlistener()
    @item.remove()
    @item = null

  serialize: -> @state

  _render: ->
    if @narrow
      React.render(<ThreadListNarrow /> , @item)
    else
      React.render(<ThreadListTabular /> , @item)

  ## TODO Put resize code in a better spot and don't hardcode the
  # breakpoint
  _onWindowResize: ->
    narrow = @_isNarrow()
    if @narrow isnt narrow
      @narrow = narrow
      @_render()

  _isNarrow: -> window.innerWidth < 1500

