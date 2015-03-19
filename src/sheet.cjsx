React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry, WorkspaceStore} = require "inbox-exports"
RetinaImg = require './components/retina-img.cjsx'
Flexbox = require './components/flexbox.cjsx'
ResizableRegion = require './components/resizable-region.cjsx'

module.exports =
Sheet = React.createClass
  displayName: 'Sheet'

  propTypes:
    type: React.PropTypes.string.isRequired
    depth: React.PropTypes.number.isRequired
    columns: React.PropTypes.arrayOf(React.PropTypes.string)
    onColumnSizeChanged: React.PropTypes.func

  getDefaultProps: ->
    columns: ['Left', 'Center', 'Right']

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unlisteners ?= []
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState(@_getStateFromStores())
    @unlisteners.push WorkspaceStore.listen (event) =>
      @setState(@_getStateFromStores())

  componentDidUpdate: ->
    @props.onColumnSizeChanged(@) if @props.onColumnSizeChanged

  shouldComponentUpdate: (nextProps, nextState) ->
    not _.isEqual(nextProps, @props) or not _.isEqual(nextState, @state)

  componentWillUnmount: ->
    unlisten() for unlisten in @unlisteners

  render: ->
    style =
      position:'absolute'
      backgroundColor:'white'
      width:'100%'
      height:'100%'
      zIndex: 1

    # Note - setting the z-index of the sheet is important, even though it's
    # always 1. Assigning a z-index creates a "stacking context" in the browser,
    # so z-indexes inside the sheet are relative to each other, but something in
    # one sheet cannot be on top of something in another sheet.
    # http://philipwalton.com/articles/what-no-one-told-you-about-z-index/

    <div name={"Sheet"}
         style={style}
         data-type={@props.type}>
      <Flexbox direction="row">
        {@_columnFlexboxComponents()}
      </Flexbox>
    </div>

  _columnFlexboxComponents: ->
    @props.columns.map (column) =>
      classes = @state[column] || []
      return if classes.length is 0

      components = classes.map ({name, view}) -> <view key={name} />

      maxWidth = _.reduce classes, ((m,{view}) -> Math.min(view.maxWidth ? 10000, m)), 10000
      minWidth = _.reduce classes, ((m,{view}) -> Math.max(view.minWidth ? 0, m)), 0
      resizable = minWidth != maxWidth && column != 'Center'

      if resizable
        if column is 'Left' then handle = ResizableRegion.Handle.Right
        if column is 'Right' then handle = ResizableRegion.Handle.Left
        <ResizableRegion key={"#{@props.type}:#{column}"}
                         name={"#{@props.type}:#{column}"}
                         data-column={column}
                         onResize={ => @props.onColumnSizeChanged(@) }
                         minWidth={minWidth}
                         maxWidth={maxWidth}
                         handle={handle}>
          <Flexbox direction="column">
            {components}
          </Flexbox>
        </ResizableRegion>
      else
        <Flexbox direction="column"
                 key={"#{@props.type}:#{column}"}
                 name={"#{@props.type}:#{column}"}
                 data-column={column}
                 style={flex: 1}>
          {components}
        </Flexbox>

  _getStateFromStores: ->
    state = {}
    state.mode = WorkspaceStore.selectedLayoutMode()

    for column in @props.columns
      views = []
      for entry in ComponentRegistry.findAllByRole("#{@props.type}:#{column}")
        continue if entry.mode? and entry.mode != state.mode
        views.push(entry)
      state["#{column}"] = views

    state

  _pop: ->
    Actions.popSheet()
