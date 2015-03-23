React = require 'react/addons'
Sheet = require './sheet'
Flexbox = require './components/flexbox'
RetinaImg = require './components/retina-img'
TimeoutTransitionGroup = require './components/timeout-transition-group'
_ = require 'underscore-plus'

{Actions,
 ComponentRegistry,
 WorkspaceStore} = require "inbox-exports"

ToolbarSpacer = React.createClass
  className: 'ToolbarSpacer'
  propTypes:
    order: React.PropTypes.number
  render: ->
    <div className="item-spacer" style={flex: 1, order:@props.order ? 0}></div>

ToolbarBack = React.createClass
  className: 'ToolbarBack'
  render: ->
    <div className="item-back" onClick={@_onClick}>
      <RetinaImg name="sheet-back.png" />
    </div>

  _onClick: ->
    Actions.popSheet()

ToolbarWindowControls = React.createClass
  displayName: 'ToolbarWindowControls'
  render: ->
    <div name="ToolbarWindowControls" className="toolbar-window-controls">
      <button className="close" onClick={ -> atom.close()}></button>
      <button className="minimize" onClick={ -> atom.minimize()}></button>
      <button className="maximize" onClick={ -> atom.maximize()}></button>
    </div>

ComponentRegistry.register
  view: ToolbarWindowControls
  name: 'ToolbarWindowControls'
  location: WorkspaceStore.Sheet.Global.Toolbar.Left

Toolbar = React.createClass
  className: 'Toolbar'

  propTypes:
    data: React.PropTypes.object
    depth: React.PropTypes.number

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unlisteners = []
    @unlisteners.push WorkspaceStore.listen (event) =>
      @setState(@_getStateFromStores())
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState(@_getStateFromStores())
    window.addEventListener("resize", @_onWindowResize)
    window.requestAnimationFrame => @recomputeLayout()

  componentWillUnmount: ->
    window.removeEventListener("resize", @_onWindowResize)
    unlistener() for unlistener in @unlisteners

  componentWillReceiveProps: (props) ->
    @replaceState(@_getStateFromStores(props))

  componentDidUpdate: ->
    # Wait for other components that are dirty (the actual columns in the sheet)
    # to update as well.
    window.requestAnimationFrame => @recomputeLayout()

  shouldComponentUpdate: (nextProps, nextState) ->
    # This is very important. Because toolbar uses ReactCSSTransitionGroup,
    # repetitive unnecessary updates can break animations and cause performance issues.
    not _.isEqual(nextProps, @props) or not _.isEqual(nextState, @state)

  render: ->
    style =
      position:'absolute'
      backgroundColor:'white'
      width:'100%'
      height:'100%'
      zIndex: 1

    toolbars = @state.columns.map (items, idx) =>
      <div style={position: 'absolute', top:0, display:'none'}
           data-column={idx}
           key={idx}>
        {@_flexboxForItems(items)}
      </div>

    <div style={style} className={"mode-#{@state.mode}"}>
      {toolbars}
    </div>
  
  _flexboxForItems: (items) ->
    elements = items.map ({view, name}) =>
      <view key={name} {...@props} />

    <TimeoutTransitionGroup
      className="item-container"
      component={Flexbox}
      direction="row"
      leaveTimeout={200}
      enterTimeout={200}
      transitionName="sheet-toolbar">
      {elements}
      <ToolbarSpacer key="spacer-50" order={-50}/>
      <ToolbarSpacer key="spacer+50" order={50}/>
    </TimeoutTransitionGroup>

  recomputeLayout: ->
    return unless @isMounted()
    
    # Find our item containers that are tied to specific columns
    columnToolbarEls = @getDOMNode().querySelectorAll('[data-column]')

    # Find the top sheet in the stack
    sheet = document.querySelector("[name='Sheet']:nth-child(#{@props.depth+1})")
    return unless sheet

    # Position item containers so they have the position and width
    # as their respective columns in the top sheet
    for columnToolbarEl in columnToolbarEls
      column = columnToolbarEl.dataset.column
      columnEl = sheet.querySelector("[data-column='#{column}']")
      continue unless columnEl

      columnToolbarEl.style.display = 'inherit'
      columnToolbarEl.style.left = "#{columnEl.offsetLeft}px"
      columnToolbarEl.style.width = "#{columnEl.offsetWidth}px"

  _onWindowResize: ->
    @recomputeLayout()
  
  _getStateFromStores: (props) ->
    props ?= @props
    state =
      mode: WorkspaceStore.selectedLayoutMode()
      columns: []

    # Add items registered to Regions in the current sheet
    for loc in @props.data.columns[state.mode]
      entries = ComponentRegistry.findAllByLocationAndMode(loc.Toolbar, state.mode)
      state.columns.push(entries)

    # Add left items registered to the Sheet instead of to a Region
    for loc in [WorkspaceStore.Sheet.Global, @props.data]
      entries = ComponentRegistry.findAllByLocationAndMode(loc.Toolbar.Left, state.mode)
      state.columns[0].push(entries...)
    state.columns[0].push(view: ToolbarBack, name: 'ToolbarBack') if @props.depth > 0

    # Add right items registered to the Sheet instead of to a Region
    for loc in [WorkspaceStore.Sheet.Global, @props.data]
      entries = ComponentRegistry.findAllByLocationAndMode(loc.Toolbar.Right, state.mode)
      state.columns[state.columns.length - 1].push(entries...)

    state


FlexboxForLocations = React.createClass
  className: 'FlexboxForLocations'

  propTypes:
    locations: React.PropTypes.arrayOf(React.PropTypes.object)

  getInitialState: ->
    @_getComponentRegistryState()

  componentDidMount: ->
    @unlistener = ComponentRegistry.listen (event) =>
      @setState(@_getComponentRegistryState())

  componentWillUnmount: ->
    @unlistener() if @unlistener

  shouldComponentUpdate: (nextProps, nextState) ->
    # Note: we actually ignore props.roles. If roles change, but we get
    # the same items, we don't need to re-render. Our render function is
    # a function of state only.
    nextItemNames = nextState.items.map (i) -> i.name
    itemNames = @state.items?.map (i) -> i.name
    !_.isEqual(nextItemNames, itemNames)

  render: ->
    elements = @state.items.map ({view, name}) =>
      <view key={name} />
    
    <Flexbox direction="row">
      {elements}
    </Flexbox>

  _getComponentRegistryState: ->
    items = []
    mode = WorkspaceStore.selectedLayoutMode()
    for location in @props.locations
      items = items.concat(ComponentRegistry.findAllByLocationAndMode(location, mode))
    {items}

module.exports =
SheetContainer = React.createClass
  className: 'SheetContainer'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = WorkspaceStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    topSheet = @state.stack[@state.stack.length - 1]

    <Flexbox direction="column">
      <TimeoutTransitionGroup  name="Toolbar" 
                               style={order:0}
                               leaveTimeout={200}
                               enterTimeout={200}
                               className="sheet-toolbar"
                               transitionName="sheet-toolbar">
        {@_toolbarElements()}
      </TimeoutTransitionGroup>

      <div name="Header" style={order:1}>
        <FlexboxForLocations locations={[topSheet.Header, WorkspaceStore.Sheet.Global.Header]}
                             type={topSheet.type}/>
      </div>

      <TimeoutTransitionGroup name="Center"
                              style={order:2, flex: 1, position:'relative'}
                              leaveTimeout={150}
                              enterTimeout={150}
                              transitionName="sheet-stack">
        {@_sheetElements()}
      </TimeoutTransitionGroup>

      <div name="Footer" style={order:3}>
        <FlexboxForLocations locations={[topSheet.Footer, WorkspaceStore.Sheet.Global.Footer]}
                             type={topSheet.type}/>
      </div>
    </Flexbox>

  _toolbarElements: ->
    @state.stack.map (data, index) ->
      <Toolbar data={data}
               ref={"toolbar-#{index}"}
               depth={index}
               key={index} />

  _sheetElements: ->
    @state.stack.map (data, index) =>
      <Sheet data={data}
             depth={index}
             key={index}
             onColumnSizeChanged={@_onColumnSizeChanged} />

  _onColumnSizeChanged: (sheet) ->
    @refs["toolbar-#{sheet.props.depth}"]?.recomputeLayout()

  _onStoreChange: ->
    _.defer => @setState(@_getStateFromStores())

  _getStateFromStores: ->
    stack: WorkspaceStore.sheetStack()

