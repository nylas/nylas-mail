React = require 'react'
ReactDOM = require 'react-dom'
Sheet = require './sheet'
Flexbox = require './components/flexbox'
RetinaImg = require './components/retina-img'
Utils = require './flux/models/utils'
{remote} = require 'electron'
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
    @state = NylasEnv.getLoadSettings()

  componentDidMount: ->
    @unlisten = NylasEnv.onWindowPropsReceived (windowProps) =>
      @setState NylasEnv.getLoadSettings()

  componentWillUnmount: ->
    @unlisten?()

  render: ->
    <div className="window-title">{@state.title}</div>

Category = null
FocusedPerspectiveStore = null
class ToolbarBack extends React.Component
  @displayName: 'ToolbarBack'

  # These stores are only required when this Toolbar is actually needed.
  # This is because loading these stores has database side effects.
  constructor: (@props) ->
    Category ?= require './flux/models/category'
    FocusedPerspectiveStore ?= require './flux/stores/focused-perspective-store'
    @state =
      categoryName: FocusedPerspectiveStore.current().name

  componentDidMount: =>
    @_unsubscriber = FocusedPerspectiveStore.listen =>
      @setState(categoryName: FocusedPerspectiveStore.current().name)

  componentWillUnmount: =>
    @_unsubscriber() if @_unsubscriber

  render: =>
    if @state.categoryName is Category.AllMailName
      title = 'All Mail'
    else if @state.categoryName
      title = _str.titleize(@state.categoryName)
    else
      title = "Back"

    <div className="item-back" onClick={@_onClick} title="Return to #{title}">
      <RetinaImg name="sheet-back.png" mode={RetinaImg.Mode.ContentIsMask} />
      <div className="item-back-title">{title}</div>
    </div>

  _onClick: =>
    Actions.popSheet()

class ToolbarWindowControls extends React.Component
  @displayName: 'ToolbarWindowControls'
  constructor: (@props) ->
    @state = {alt: false}

  componentDidMount: =>
    if process.platform is 'darwin'
      window.addEventListener('keydown', @_onAlt)
      window.addEventListener('keyup', @_onAlt)

  componentWillUnmount: =>
    if process.platform is 'darwin'
      window.removeEventListener('keydown', @_onAlt)
      window.removeEventListener('keyup', @_onAlt)

  render: =>
    <div name="ToolbarWindowControls" className="toolbar-window-controls alt-#{@state.alt}">
      <button tabIndex={-1} className="close" onClick={ -> NylasEnv.close()}></button>
      <button tabIndex={-1} className="minimize" onClick={ -> NylasEnv.minimize()}></button>
      <button tabIndex={-1} className="maximize" onClick={@_onMaximize}></button>
    </div>

  _onAlt: (event) =>
    @setState(alt: event.altKey) if @state.alt isnt event.altKey

  _onMaximize: (event) =>
    if process.platform is 'darwin' and not event.altKey
      NylasEnv.setFullScreen(!NylasEnv.isFullScreen())
    else
      NylasEnv.maximize()

class ToolbarMenuControl extends React.Component
  @displayName: 'ToolbarMenuControl'
  render: =>
    <div className="toolbar-menu-control">
      <button tabIndex={-1} className="btn btn-toolbar" onClick={@_openMenu}>
        <RetinaImg name="windows-menu-icon.png" mode={RetinaImg.Mode.ContentIsMask} />
      </button>
    </div>

  _openMenu: =>
    applicationMenu = remote.getGlobal('application').applicationMenu
    applicationMenu.menu.popup(NylasEnv.getCurrentWindow())

ComponentRegistry.register ToolbarWindowControls,
  location: WorkspaceStore.Sheet.Global.Toolbar.Left

ComponentRegistry.register ToolbarMenuControl,
  location: WorkspaceStore.Sheet.Global.Toolbar.Right

class Toolbar extends React.Component
  @displayName: 'Toolbar'

  @propTypes:
    data: React.PropTypes.object
    depth: React.PropTypes.number

  @childContextTypes:
    sheetDepth: React.PropTypes.number
  getChildContext: =>
    sheetDepth: @props.depth

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @mounted = true
    @unlisteners = []
    @unlisteners.push WorkspaceStore.listen (event) =>
      @setState(@_getStateFromStores())
    @unlisteners.push ComponentRegistry.listen (event) =>
      @setState(@_getStateFromStores())
    window.addEventListener("resize", @_onWindowResize)
    window.requestAnimationFrame => @recomputeLayout()

  componentWillUnmount: =>
    @mounted = false
    window.removeEventListener("resize", @_onWindowResize)
    unlistener() for unlistener in @unlisteners

  componentWillReceiveProps: (props) =>
    @setState(@_getStateFromStores(props))

  componentDidUpdate: =>
    # Wait for other components that are dirty (the actual columns in the sheet)
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
           className="toolbar-#{@state.columnNames[idx]}"
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

    <Flexbox className="item-container" direction="row">
      {elements}
      <ToolbarSpacer key="spacer-50" order={-50}/>
      <ToolbarSpacer key="spacer+50" order={50}/>
    </Flexbox>

  recomputeLayout: =>
    # Yes this really happens - do not remove!
    return unless @mounted

    # Find our item containers that are tied to specific columns
    columnToolbarEls = ReactDOM.findDOMNode(@).querySelectorAll('[data-column]')

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
      columnNames: []

    # Add items registered to Regions in the current sheet
    if @props.data?.columns[state.mode]?
      for loc in @props.data.columns[state.mode]
        continue if WorkspaceStore.isLocationHidden(loc)
        entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar, mode: state.mode})
        state.columns.push(entries)
        state.columnNames.push(loc.Toolbar.id.split(":")[0]) if entries

    # Add left items registered to the Sheet instead of to a Region
    for loc in [WorkspaceStore.Sheet.Global, @props.data]
      entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar.Left, mode: state.mode})
      state.columns[0]?.push(entries...)
    if @props.depth > 0
      state.columns[0]?.push(ToolbarBack)

    # Add right items registered to the Sheet instead of to a Region
    for loc in [WorkspaceStore.Sheet.Global, @props.data]
      entries = ComponentRegistry.findComponentsMatching({location: loc.Toolbar.Right, mode: state.mode})
      state.columns[state.columns.length - 1]?.push(entries...)
    if state.mode is "popout"
      state.columns[0]?.push(WindowTitle)

    state

module.exports = Toolbar
