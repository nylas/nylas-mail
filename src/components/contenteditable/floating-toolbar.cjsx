_ = require 'underscore'
classNames = require 'classnames'
React = require 'react'

{Utils, DOMUtils, ExtensionRegistry} = require 'nylas-exports'

# Positions and renders a FloatingToolbar in the composer.
#
# The FloatingToolbar declaratively chooses a Component to render. Only
# extensions that expose a `toolbarComponentConfig` will be considered.
# Whether or not there's an available component to render determines
# whether or not the FloatingToolbar is visible.
#
# There's no `toolbarVisible` state. It uses the existance of a
# ToolbarComponent to determine what to display.
#
# The {ToolbarButtonManager} and the {LinkManager} are `coreExtensions`
# that declaratively register the special `<ToolbarButtons/>` component
# and the `<LinkEditor />` component.
class FloatingToolbar extends React.Component
  @displayName: "FloatingToolbar"

  # We are passed an array of Extensions. Those that implement the
  # `toolbarButton` and/or the `toolbarComponent` methods will be
  # injected into the Toolbar.
  #
  # Every time the `innerState` of the `Contenteditable` change, we get
  # passed the data as new `innerProps`.
  @propTypes:
    atomicEdit: React.PropTypes.func
    extensions: React.PropTypes.array
  @innerPropTypes:
    dragging: React.PropTypes.bool
    selection: React.PropTypes.object
    doubleDown: React.PropTypes.bool
    hoveringOver: React.PropTypes.object
    editableNode: React.PropTypes.object

  @defaultProps:
    extensions: []
  @defaultInnerProps:
    dragging: false
    selection: null
    doubleDown: false
    hoveringOver: null
    editableNode: null

  constructor: (@props) ->
    @state =
      toolbarTop: 0
      toolbarMode: "buttons"
      toolbarLeft: 0
      toolbarPos: "above"
      editAreaWidth: 9999 # This will get set on first selection
      toolbarWidth: 0
      toolbarHeight: 0
      toolbarComponent: null
      toolbarLocationRef: null
      toolbarComponentProps: {}
      hidePointer: false
    @innerProps = FloatingToolbar.defaultInnerProps

  shouldComponentUpdate: (nextProps, nextState) ->
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  # Some properties (like whether we're dragging or clicking the mouse)
  # should in a strict-sense be props, but update in a way that's not
  # performant to got through the full React re-rendering cycle,
  # especially given the complexity of the composer component.
  #
  # We call these performance-optimized props & state innerProps and
  # innerState.
  componentWillReceiveInnerProps: (nextInnerProps={}) =>
    fullProps = _.extend({}, @props, nextInnerProps)
    @innerProps = _.extend @innerProps, nextInnerProps
    @setState(@_getStateFromProps(fullProps))

  componentWillReceiveProps: (nextProps) =>
    fullProps = _.extend(@innerProps, nextProps)
    @setState(@_getStateFromProps(fullProps))

  # The context menu, when activated, needs to make sure that the toolbar
  # is closed. Unfortunately, since there's no onClose callback for the
  # context menu, we can't hook up a reliable declarative state to the
  # menu. We break our declarative pattern in this one case.
  forceClose: ->
    @setState toolbarVisible: false

  # We render a ToolbarComponent in a floating frame.
  render: ->
    ToolbarComponent = @state.toolbarComponent
    return false unless ToolbarComponent

    <div className="floating-toolbar-container">
      <div ref="floatingToolbar"
           className={@_toolbarClasses()}
           style={@_toolbarStyles()}>

        {@_renderPointer()}
        <ToolbarComponent {...@state.toolbarComponentProps} />
      </div>
    </div>

  _getStateFromProps: (props) ->
    toolbarComponentState = @_getToolbarComponentData(props)
    if toolbarComponentState.toolbarLocationRef
      positionState = @_calculatePositionState(props, toolbarComponentState)
    else positionState = {}

    return _.extend {}, toolbarComponentState, positionState

  # If this returns a `null` component, that means we don't want to show
  # anything.
  _getToolbarComponentData: (props) ->
    toolbarComponent = null
    toolbarWidth = 0
    toolbarHeight = 0
    toolbarLocationRef = null
    hidePointer = false
    toolbarComponentProps = {}

    for extension in props.extensions
      try
        params = extension.toolbarComponentConfig?(toolbarState: props) ? {}
        if params.component
          toolbarComponent = params.component
          toolbarComponentProps = params.props ? {}
          toolbarLocationRef = params.locationRefNode
          toolbarWidth = params.width
          toolbarHeight = params.height
          if params.hidePointer
            hidePointer = params.hidePointer
      catch error
        NylasEnv.reportError(error)

    if toolbarComponent and not toolbarLocationRef
      throw new Error("You must provide a locationRefNode for #{toolbarComponent.displayName}. It must be either a DOM Element or a Range.")

    return {toolbarComponent, toolbarComponentProps, toolbarLocationRef, toolbarWidth, toolbarHeight, hidePointer}

  @CONTENT_PADDING: 15

  _calculatePositionState: (props, {toolbarLocationRef, toolbarWidth, toolbarHeight}) =>
    editableNode = props.editableNode

    if not _.isFunction(toolbarLocationRef.getBoundingClientRect)
      throw new Error("Your locationRefNode must implement getBoundingClientRect. Be aware that Text nodes do not implement this, but Element nodes do. Find the nearest Element relative.")

    referenceRect = toolbarLocationRef.getBoundingClientRect()

    if not editableNode or not referenceRect or DOMUtils.isEmptyBoundingRect(referenceRect)
      return {toolbarTop: 0, toolbarLeft: 0, editAreaWidth: 0, toolbarPos: 'above'}

    TOP_PADDING = 10

    BORDER_RADIUS_PADDING = 15

    editArea = editableNode.getBoundingClientRect()

    calcLeft = (referenceRect.left - editArea.left) + referenceRect.width/2
    calcLeft = Math.min(Math.max(calcLeft, FloatingToolbar.CONTENT_PADDING+BORDER_RADIUS_PADDING), editArea.width - BORDER_RADIUS_PADDING)

    calcTop = referenceRect.top - editArea.top - toolbarHeight - 14
    if @state.hidePointer
      calcTop += 10
    toolbarPos = "above"
    if calcTop < TOP_PADDING
      calcTop = referenceRect.top - editArea.top + referenceRect.height + TOP_PADDING + 4
      if @state.hidePointer
        calcTop -= 10
      toolbarPos = "below"

    maxWidth = editArea.width - FloatingToolbar.CONTENT_PADDING * 2

    return {
      toolbarTop: calcTop
      toolbarLeft: calcLeft
      toolbarWidth: Math.min(maxWidth, toolbarWidth)
      toolbarHeight: toolbarHeight
      editAreaWidth: editArea.width
      toolbarPos: toolbarPos
    }

  _toolbarClasses: =>
    classes = {}
    classes[@state.toolbarPos] = true
    classNames _.extend classes,
      "floating-toolbar": true
      "toolbar": true

  _toolbarStyles: =>
    styles =
      left: @_toolbarLeft()
      top: @state.toolbarTop
      width: @state.toolbarWidth
      height: @state.toolbarHeight
    return styles

  _toolbarLeft: =>
    max = Math.max(@state.editAreaWidth - @state.toolbarWidth - FloatingToolbar.CONTENT_PADDING, FloatingToolbar.CONTENT_PADDING)
    left = Math.min(Math.max(@state.toolbarLeft - @state.toolbarWidth/2, FloatingToolbar.CONTENT_PADDING), max)
    return left

  _toolbarPointerStyles: =>
    POINTER_WIDTH = 6 + 2 #2px of border-radius
    max = @state.editAreaWidth - FloatingToolbar.CONTENT_PADDING
    min = FloatingToolbar.CONTENT_PADDING
    absoluteLeft = Math.max(Math.min(@state.toolbarLeft, max), min)
    relativeLeft = absoluteLeft - @_toolbarLeft()

    left = Math.max(Math.min(relativeLeft, @state.toolbarWidth-POINTER_WIDTH), POINTER_WIDTH)
    styles =
      left: left
    return styles

  _renderPointer: =>
    unless @state.hidePointer
      return <div className="toolbar-pointer" style={@_toolbarPointerStyles()}></div>

module.exports = FloatingToolbar
