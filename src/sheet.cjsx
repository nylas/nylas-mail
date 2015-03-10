React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry} = require "inbox-exports"
Flexbox = require './components/flexbox.cjsx'
ResizableRegion = require './components/resizable-region.cjsx'


ToolbarSpacer = React.createClass
  propTypes:
    order: React.PropTypes.number
  render: ->
    <div style={flex: 1, order:@props.order ? 0}></div>

module.exports =
Sheet = React.createClass
  displayName: 'Sheet'

  propTypes:
    type: React.PropTypes.string.isRequired
    depth: React.PropTypes.number.isRequired
    columns: React.PropTypes.arrayOf(React.PropTypes.string)

  getDefaultProps: ->
    columns: ['Left', 'Center', 'Right']

  getInitialState: ->
    @_getComponentRegistryState()

  componentDidMount: ->
    @unlistener = ComponentRegistry.listen (event) =>
      @setState(@_getComponentRegistryState())

  componentWillUnmount: ->
    @unlistener() if @unlistener

  render: ->
    style =
      position:'absolute'
      backgroundColor:'white'
      width:'100%'
      height:'100%'

    <div name={"Sheet-#{@props.type}"} style={style}>
      <Flexbox direction="row">
        {@_backButtonComponent()}
        {@_columnFlexboxComponents()}
      </Flexbox>
    </div>

  _backButtonComponent: ->
    return [] if @props.depth is 0
    <div onClick={@_pop}>
      Back
    </div>

  _columnFlexboxComponents: ->
    @props.columns.map (column) =>
      classes = @state[column] || []
      return if classes.length is 0

      components = classes.map (c) => <c {...@props} />
      components.push(@_columnToolbarComponent(column))

      maxWidth = _.reduce classes, ((m,c) -> Math.min(c.maxWidth ? 10000, m)), 10000
      minWidth = _.reduce classes, ((m,c) -> Math.max(c.minWidth ? 0, m)), 0
      resizable = minWidth != maxWidth && column != 'Center'

      if resizable
        if column is 'Left' then handle = ResizableRegion.Handle.Right
        if column is 'Right' then handle = ResizableRegion.Handle.Left
        <ResizableRegion minWidth={minWidth} maxWidth={maxWidth} handle={handle}>
          <Flexbox direction="column" name={"#{@props.type}:#{column}"}>
            {components}
          </Flexbox>
        </ResizableRegion>
      else
        <Flexbox direction="column" name={"#{@props.type}:#{column}"} style={flex: 1}>
          {components}
        </Flexbox>

  _columnToolbarComponent: (column) ->
    components = @state["#{column}Toolbar"].map (item) =>
      <item {...@props} />

    <div className="sheet-column-toolbar">
      <Flexbox direction="row">
        {components}
        <ToolbarSpacer order={-50}/>
        <ToolbarSpacer order={50}/>
      </Flexbox>
    </div>

  # Load components that are part of our sheet. For each column,
  # (eg 'Center') we look for items with a matching `role`. We
  # then pull toolbar items the following places:
  #
  # - Root:Center:Toolbar
  # - ComposeButton:Toolbar
  #
  _getComponentRegistryState: ->
    state = {}
    for column in @props.columns
      views = []
      toolbarViews = ComponentRegistry.findAllViewsByRole("#{@props.type}:#{column}:Toolbar")

      for {view, name} in ComponentRegistry.findAllByRole("#{@props.type}:#{column}")
        toolbarViews = toolbarViews.concat(ComponentRegistry.findAllViewsByRole("#{name}:Toolbar"))
        views.push(view)

      state["#{column}"] = views
      state["#{column}Toolbar"] = toolbarViews
    state

  _pop: ->
    Actions.popSheet()
