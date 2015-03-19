React = require 'react/addons'
Sheet = require './sheet'
Flexbox = require './components/flexbox.cjsx'
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
  role: 'Global:Left:Toolbar'

Toolbar = React.createClass
  className: 'Toolbar'

  propTypes:
    type: React.PropTypes.string
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

    toolbars = @state.itemsForColumns.map ({column, items}) =>
      <div style={position: 'absolute', top:0, display:'none'}
           data-column={column}
           key={column}>
        {@_flexboxForItems(items)}
      </div>

    <div style={style}>
      {toolbars}
    </div>
  
  _flexboxForItems: (items) ->
    components = items.map ({view, name}) =>
      <view key={name} {...@props} />

    <TimeoutTransitionGroup
      className="item-container"
      component={Flexbox}
      direction="row"
      leaveTimeout={200}
      enterTimeout={200}
      transitionName="sheet-toolbar">
      {components}
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
      itemsForColumns: []

    items = {}
    for column in ["Left", "Center", "Right"]
      items[column] = []
      for role in ["Global:#{column}:Toolbar", "#{props.type}:#{column}:Toolbar"]
        for entry in ComponentRegistry.findAllByRole(role)
          continue if entry.mode? and entry.mode != state.mode
          items[column].push(entry)
        
    if @props.depth > 0
      items['Left'].push(view: ToolbarBack, name: 'ToolbarBack')

    # If the left or right column does not contain any components, it won't
    # be in the sheet. Go ahead and shift those toolbar items into the center
    # region.
    for column in ["Left", "Right"]
      if ComponentRegistry.findAllByRole("#{props.type}:#{column}").length is 0
        items['Center'].push(items[column]...)
        delete items[column]

    for key, val of items
      state.itemsForColumns.push({column: key, items: val}) if val.length > 0
    state


FlexboxForRoles = React.createClass
  className: 'FlexboxForRoles'

  propTypes:
    roles: React.PropTypes.arrayOf(React.PropTypes.string)

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
    components = @state.items.map ({view, name}) =>
      <view key={name} />
    
    <Flexbox direction="row">
      {components}
    </Flexbox>

  _getComponentRegistryState: ->
    items = []
    for role in @props.roles
      items = items.concat(ComponentRegistry.findAllByRole(role))
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
    topSheetType = @state.stack[@state.stack.length - 1]

    <Flexbox direction="column">
      <TimeoutTransitionGroup  name="Toolbar" 
                               style={order:0}
                               leaveTimeout={200}
                               enterTimeout={200}
                               className="sheet-toolbar"
                               transitionName="sheet-toolbar">
        {@_toolbarComponents()}
      </TimeoutTransitionGroup>

      <div name="Top" style={order:1}>
        <FlexboxForRoles roles={["Global:Top", "#{topSheetType}:Top"]}
                         type={topSheetType}/>
      </div>

      <TimeoutTransitionGroup name="Center"
                              style={order:2, flex: 1, position:'relative'}
                              leaveTimeout={150}
                              enterTimeout={150}
                              transitionName="sheet-stack">
        {@_sheetComponents()}
      </TimeoutTransitionGroup>

      <div name="Footer" style={order:3}>
        <FlexboxForRoles roles={["Global:Footer", "#{topSheetType}:Footer"]}
                         type={topSheetType}/>
      </div>
    </Flexbox>

  _toolbarComponents: ->
    @state.stack.map (type, index) ->
      <Toolbar type={type}
               ref={"toolbar-#{index}"}
               depth={index}
               key={index} />

  _sheetComponents: ->
    @state.stack.map (type, index) =>
      <Sheet type={type}
             depth={index}
             key={index}
             onColumnSizeChanged={@_onColumnSizeChanged} />

  _onColumnSizeChanged: (sheet) ->
    @refs["toolbar-#{sheet.props.depth}"]?.recomputeLayout()

  _onStoreChange: ->
    _.defer => @setState(@_getStateFromStores())

  _getStateFromStores: ->
    stack: WorkspaceStore.sheetStack()

