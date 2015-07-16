React = require 'react/addons'
Sheet = require './sheet'
Flexbox = require './components/flexbox'
RetinaImg = require './components/retina-img'
CategoryStore = require './flux/stores/category-store'
FocusedCategoryStore = require './flux/stores/focused-category-store'
TimeoutTransitionGroup = require './components/timeout-transition-group'
_str = require 'underscore.string'
_ = require 'underscore'

{Actions,
 ComponentRegistry,
 WorkspaceStore} = require "nylas-exports"

class ToolbarSpacer extends React.Component
  @displayName: 'ToolbarSpacer'
  @propTypes:
    order: React.PropTypes.number

  render: =>
    <div className="item-spacer" style={flex: 1, order:@props.order ? 0}></div>

class WindowTitle extends React.Component
  @displayName: "WindowTitle"

  constructor: (@props) ->
    @state = atom.getLoadSettings()

  componentDidMount: ->
    @unlisten = atom.onWindowPropsReceived (windowProps) =>
      @setState atom.getLoadSettings()

  componentWillUnmount: -> @unlisten()

  render: ->
    <div className="window-title">{@state.title}</div>

class ToolbarBack extends React.Component
  @displayName: 'ToolbarBack'

  constructor: (@props) ->
    @state =
      categoryName: FocusedCategoryStore.categoryName()

  componentDidMount: =>
    @_unsubscriber = FocusedCategoryStore.listen =>
      @setState(categoryName: FocusedCategoryStore.categoryName())

  componentWillUnmount: =>
    @_unsubscriber() if @_unsubscriber

  render: =>
    if @state.categoryName is CategoryStore.AllMailName
      title = 'All Mail'
    else if @state.categoryName
      title = _str.titleize(@state.categoryName)
    else
      title = "Back"

    <div className="item-back" onClick={@_onClick}>
      <RetinaImg name="sheet-back.png" mode={RetinaImg.Mode.ContentIsMask} />
      <div className="item-back-title">{title}</div>
    </div>

  _onClick: =>
    Actions.popSheet()

class ToolbarWindowControls extends React.Component
  @displayName: 'ToolbarWindowControls'
  render: =>
    <div name="ToolbarWindowControls" className="toolbar-window-controls">
      <button className="close" onClick={ -> atom.close()}></button>
      <button className="minimize" onClick={ -> atom.minimize()}></button>
      <button className="maximize" onClick={ -> atom.maximize()}></button>
    </div>

ComponentRegistry.register ToolbarWindowControls,
  location: WorkspaceStore.Sheet.Global.Toolbar.Left

class Toolbar extends React.Component
  @displayName: 'Toolbar'

  @propTypes:
    data: React.PropTypes.object
    depth: React.PropTypes.number

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @unlisteners = []
    @unlisteners.push WorkspaceStore.listen (event) =>
      @setState(@_getStateFromStores())
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState(@_getStateFromStores())
    window.addEventListener("resize", @_onWindowResize)
    window.requestAnimationFrame => @recomputeLayout()

  componentWillUnmount: =>
    window.removeEventListener("resize", @_onWindowResize)
    unlistener() for unlistener in @unlisteners

  componentWillReceiveProps: (props) =>
    @setState(@_getStateFromStores(props))

  componentDidUpdate: =>
    # Wait for other components that are dirty (the actual columns in the sheet)
    # to update as well.
    window.requestAnimationFrame => @recomputeLayout()

  shouldComponentUpdate: (nextProps, nextState) =>
    # This is very important. Because toolbar uses ReactCSSTransitionGroup,
    # repetitive unnecessary updates can break animations and cause performance issues.
    not _.isEqual(nextProps, @props) or not _.isEqual(nextState, @state)

  render: =>
    style =
      position:'absolute'
      width:'100%'
      height:'100%'
      zIndex: 1

    toolbars = @state.columns.map (components, idx) =>
      <div style={position: 'absolute', top:0, display:'none'}
           data-column={idx}
           key={idx}>
        {@_flexboxForComponents(components)}
      </div>

    <div style={style} className={"sheet-toolbar-container mode-#{@state.mode}"}>
      {toolbars}
    </div>

  _flexboxForComponents: (components) =>
    elements = components.map (component) =>
      <component key={component.displayName} {...@props} />

    <TimeoutTransitionGroup
      className="item-container"
      component={Flexbox}
      direction="row"
      leaveTimeout={125}
      enterTimeout={125}
      transitionName="sheet-toolbar">
      {elements}
      <ToolbarSpacer key="spacer-50" order={-50}/>
      <ToolbarSpacer key="spacer+50" order={50}/>
    </TimeoutTransitionGroup>

  recomputeLayout: =>
    # Find our item containers that are tied to specific columns
    columnToolbarEls = React.findDOMNode(@).querySelectorAll('[data-column]')

    # Find the top sheet in the stack
    sheet = document.querySelectorAll("[name='Sheet']")[@props.depth]
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

  _onWindowResize: =>
    @recomputeLayout()

  _getStateFromStores: (props) =>
    props ?= @props
    state =
      mode: WorkspaceStore.layoutMode()
      columns: []

    # Add items registered to Regions in the current sheet
    if @props.data?.columns[state.mode]?
      for loc in @props.data.columns[state.mode]
        entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar, mode: state.mode})
        state.columns.push(entries)

    # Add left items registered to the Sheet instead of to a Region
    for loc in [WorkspaceStore.Sheet.Global, @props.data]
      entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar.Left, mode: state.mode})
      state.columns[0]?.push(entries...)
    state.columns[0]?.push(ToolbarBack) if @props.depth > 0

    # Add right items registered to the Sheet instead of to a Region
    for loc in [WorkspaceStore.Sheet.Global, @props.data]
      entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar.Right, mode: state.mode})
      state.columns[state.columns.length - 1]?.push(entries...)

    if state.mode is "popout"
      state.columns[0]?.push(WindowTitle)

    state

module.exports = Toolbar
