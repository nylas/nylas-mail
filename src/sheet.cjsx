React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry, WorkspaceStore} = require "inbox-exports"
RetinaImg = require './components/retina-img'
Flexbox = require './components/flexbox'
ResizableRegion = require './components/resizable-region'

FLEX = 10000

module.exports =
Sheet = React.createClass
  displayName: 'Sheet'

  propTypes:
    data: React.PropTypes.object.isRequired
    depth: React.PropTypes.number.isRequired
    onColumnSizeChanged: React.PropTypes.func

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
         data-type={@props.data.type}>
      <Flexbox direction="row">
        {@_columnFlexboxElements()}
      </Flexbox>
    </div>

  _columnFlexboxElements: ->
    @state.columns.map ({entries, maxWidth, minWidth, handle, id}, idx) =>
      elements = entries.map ({name, view}) -> <view key={name} />
      if minWidth != maxWidth and maxWidth < FLEX
        <ResizableRegion key={"#{@props.type}:#{idx}"}
                         name={"#{@props.type}:#{idx}"}
                         className={"column-#{id}"}
                         data-column={idx}
                         onResize={ => @props.onColumnSizeChanged(@) }
                         minWidth={minWidth}
                         maxWidth={maxWidth}
                         handle={handle}>
          <Flexbox direction="column">
            {elements}
          </Flexbox>
        </ResizableRegion>
      else
        <Flexbox direction="column"
                 key={"#{@props.type}:#{idx}"}
                 name={"#{@props.type}:#{idx}"}
                 className={"column-#{id}"}
                 data-column={idx}
                 style={flex: 1}>
          {elements}
        </Flexbox>

  _getStateFromStores: ->
    state = 
      mode: WorkspaceStore.selectedLayoutMode()
      columns: []

    widest = -1
    widestWidth = -1

    for location, idx in @props.data.columns[state.mode]
      entries = ComponentRegistry.findAllByLocationAndMode(location, state.mode)
      maxWidth = _.reduce entries, ((m,{view}) -> Math.min(view.maxWidth ? 10000, m)), 10000
      minWidth = _.reduce entries, ((m,{view}) -> Math.max(view.minWidth ? 0, m)), 0
      col = {entries, maxWidth, minWidth, id: location.id}
      state.columns.push(col)

      if maxWidth > widestWidth
        widestWidth = maxWidth
        widest = idx

    # Once we've accumulated all the React components for the columns,
    # ensure that at least one column has a huge max-width so that the columns
    # expand to fill the window. This may make items in the column unhappy, but
    # we pick the column with the highest max-width so the effect is minimal.
    state.columns[widest].maxWidth = FLEX

    # Assign flexible edges based on whether items are to the left or right
    # of the flexible column (which has no edges)
    state.columns[i].handle = ResizableRegion.Handle.Right for i in [0..widest-1] by 1
    state.columns[i].handle = ResizableRegion.Handle.Left  for i in [widest..state.columns.length-1] by 1
    state

  _pop: ->
    Actions.popSheet()
