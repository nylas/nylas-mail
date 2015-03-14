React = require 'react/addons'
Sheet = require './sheet'
TitleBar = require './titlebar'
Flexbox = require './components/flexbox.cjsx'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup

{Actions,
 ComponentRegistry,
 WorkspaceStore} = require "inbox-exports"

ToolbarSpacer = React.createClass
  className: 'ToolbarSpacer'
  propTypes:
    order: React.PropTypes.number

  render: ->
    <div className="item-spacer" style={flex: 1, order:@props.order ? 0}></div>


Toolbar = React.createClass
  className: 'Toolbar'
  propTypes:
    type: React.PropTypes.string

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unlisteners = []
    @unlisteners.push WorkspaceStore.listen (event) =>
      @setState(@_getStateFromStores())
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState(@_getStateFromStores())
    window.addEventListener "resize", (event) =>
      @recomputeLayout()

  componentWillUnmount: ->
    @unlistener() if @unlistener

  componentWillReceiveProps: (props) ->
    @setState(@_getStateFromStores(props))

  componentDidUpdate: ->
    # Wait for other components that are dirty (the actual columns in the sheet)
    # to update as well.
    setTimeout(( => @recomputeLayout()), 1)

  render: ->
    # The main toolbar contains items with roles <sheet type>:Toolbar
    # and Global:Toolbar
    mainToolbar = @_flexboxForItems(@state.items)

    # Column toolbars contain items with roles attaching them to items
    # in the sheet. Ex: MessageList:Toolbar items appear in the column
    # toolbar for the column containing <MessageList/>.
    columnToolbars = @state.itemsForColumns.map ({column, name, items}) =>
      <div style={position: 'absolute', top:0, display:'none'}
           data-owner-name={name}
           data-column={column}
           key={column}>
        {@_flexboxForItems(items)}
      </div>

    <ReactCSSTransitionGroup transitionName="sheet-toolbar">
      {mainToolbar}
      {columnToolbars}
    </ReactCSSTransitionGroup>
  
  _flexboxForItems: (items) ->
    components = items.map ({view, name}) =>
      <view key={name} {...@props} />

    <ReactCSSTransitionGroup
      className="item-container"
      component={Flexbox}
      direction="row"
      transitionName="sheet-toolbar">
      {components}
      <ToolbarSpacer key="spacer-50" order={-50}/>
      <ToolbarSpacer key="spacer+50" order={50}/>
    </ReactCSSTransitionGroup>

  recomputeLayout: ->
    return unless @isMounted()
    
    # Find our item containers that are tied to specific columns
    columnToolbarEls = @getDOMNode().querySelectorAll('[data-column]')

    # Find the top sheet in the stack
    sheet = document.querySelector("[name='Sheet']:last-child")
    
    # Position item containers so they have the position and width
    # as their respective columns in the top sheet
    for columnToolbarEl in columnToolbarEls
      column = columnToolbarEl.dataset.column
      columnEl = sheet.querySelector("[data-column='#{column}']")
      continue unless columnEl

      columnToolbarEl.style.display = 'inherit'
      columnToolbarEl.style.left = "#{columnEl.offsetLeft}px"
      columnToolbarEl.style.width = "#{columnEl.offsetWidth}px"

  _getStateFromStores: (props) ->
    props ?= @props
    state =
      mode: WorkspaceStore.selectedLayoutMode()
      items: []
      itemsForColumns: []

    for role in ["Global:Toolbar", "#{props.type}:Toolbar"]
      for entry in ComponentRegistry.findAllByRole(role)
        continue if entry.mode? and entry.mode != state.mode
        state.items.push(entry)

    for column in ["Left", "Center", "Right"]
      role = "#{props.type}:#{column}:Toolbar"
      items = []
      for entry in ComponentRegistry.findAllByRole(role)
        continue if entry.mode? and entry.mode != state.mode
        items.push(entry)
      if items.length > 0
        state.itemsForColumns.push({column, name, items})
        
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

  render: ->
    components = @state.items.map ({view, name}) =>
      <view key={name} {...@props} />
    
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
      <TitleBar />
      <div name="Toolbar" style={order:0} className="sheet-toolbar">
        <Toolbar ref="toolbar" type={topSheetType}/>
      </div>
      <div name="Top" style={order:1}>
        <FlexboxForRoles roles={["Global:Top", "#{topSheetType}:Top"]}
                         type={topSheetType}/>
      </div>
      <div name="Center" style={order:2, flex: 1, position:'relative'}>
        <ReactCSSTransitionGroup transitionName="sheet-stack">
          {@_sheetComponents()}
        </ReactCSSTransitionGroup>
      </div>
      <div name="Footer" style={order:3}>
        <FlexboxForRoles roles={["Global:Footer", "#{topSheetType}:Footer"]}
                         type={topSheetType}/>
      </div>
    </Flexbox>

  _sheetComponents: ->
    @state.stack.map (type, index) =>
      <Sheet type={type}
             depth={index}
             key={index}
             onColumnSizeChanged={@_onColumnSizeChanged} />

  _onColumnSizeChanged: ->
    @refs.toolbar.recomputeLayout()

  _onStoreChange: ->
    @setState @_getStateFromStores()

  _getStateFromStores: ->
    stack: WorkspaceStore.sheetStack()

