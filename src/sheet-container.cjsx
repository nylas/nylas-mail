React = require 'react'
SheetStore = require './sheet-store'
Sheet = require './sheet'
{Actions,ComponentRegistry} = require "inbox-exports"
Flexbox = require './components/flexbox.cjsx'
ReactCSSTransitionGroup = React.addons.CSSTransitionGroup


ToolbarSpacer = React.createClass
  propTypes:
    order: React.PropTypes.number

  render: ->
    <div style={flex: 1, order:@props.order ? 0}></div>


Toolbar = React.createClass
  propTypes:
    type: React.PropTypes.string

  getInitialState: ->
    @_getComponentRegistryState()

  componentDidMount: ->
    @unlistener = ComponentRegistry.listen (event) =>
      @setState(@_getComponentRegistryState())

  componentWillUnmount: ->
    @unlistener() if @unlistener

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
    columnToolbars = @state.itemsForViews.map ({column, name, items}) =>
      <div style={position: 'absolute', top:0}
           data-owner-name={name}
           data-column={column}>
        {@_flexboxForItems(items)}
      </div>

    <div>
      {mainToolbar}
      {columnToolbars}
    </div>
  
  _flexboxForItems: (items) ->
    components = items.map (item) =>
      <item {...@props} />

    <Flexbox direction="row">
      {components}
      <ToolbarSpacer order={-50}/>
      <ToolbarSpacer order={50}/>
    </Flexbox>

  recomputeLayout: ->
    return unless @isMounted()
    
    # Find our item containers that are tied to specific columns
    columnToolbarEls = this.getDOMNode().querySelectorAll('[data-column]')

    # Find the top sheet in the stack
    sheet = document.querySelector("[name='Sheet']:last-child")
    
    # Position item containers so they have the position and width
    # as their respective columns in the top sheet
    for columnToolbarEl in columnToolbarEls
      column = columnToolbarEl.dataset.column
      columnEl = sheet.querySelector("[data-column='#{column}']")
      continue unless columnEl
      columnToolbarEl.style.left = "#{columnEl.offsetLeft}px"
      columnToolbarEl.style.width = "#{columnEl.offsetWidth}px"

  _getComponentRegistryState: ->
    items = []
    items.push(ComponentRegistry.findAllViewsByRole("Global:Toolbar")...)
    items.push(ComponentRegistry.findAllViewsByRole("#{@props.type}:Toolbar")...)

    itemsForViews = []
    for column in ['Left', 'Right', 'Center']
      for {view, name} in ComponentRegistry.findAllByRole("#{@props.type}:#{column}")
        itemsForView = ComponentRegistry.findAllViewsByRole("#{name}:Toolbar")
        if itemsForView.length > 0
          itemsForViews.push({column, name, items: itemsForView})
        
    {items, itemsForViews}


FlexboxForRoles = React.createClass
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
    components = @state.items.map (item) =>
      <item {...@props} />
    
    <Flexbox direction="row">
      {components}
    </Flexbox>

  _getComponentRegistryState: ->
    items = []
    for role in @props.roles
      items = items.concat(ComponentRegistry.findAllViewsByRole(role))
    {items}

module.exports =
SheetContainer = React.createClass

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = SheetStore.listen @_onStoreChange

  # It's important that every React class explicitly stops listening to
  # atom events before it unmounts. Thank you event-kit
  # This can be fixed via a Reflux mixin
  componentWillUnmount: ->
    @unsubscribe() if @unsubscribe

  render: ->
    topSheetType = @state.stack[@state.stack.length - 1]
    
    <Flexbox direction="column">
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
    stack: SheetStore.stack()

