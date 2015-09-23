_ = require 'underscore'
React = require 'react'

{Utils, DOMUtils} = require 'nylas-exports'

FloatingToolbar = require './floating-toolbar'

# This is responsible for the logic required to position a floating
# toolbar
class FloatingToolbarContainer extends React.Component
  @displayName: "FloatingToolbarContainer"

  @propTypes:
    # A function we call when we would like to request to change the
    # current selection
    onSaveUrl: React.PropTypes.func

    # When an extension wants to mutate the DOM, it passes `onDomMutator`
    # a callback function. That callback is expecting to be passed the
    # latest DOM object and may modify it in place.
    onDomMutator: React.PropTypes.func

  @innerPropTypes:
    links: React.PropTypes.array
    dragging: React.PropTypes.bool
    selection: React.PropTypes.object
    doubleDown: React.PropTypes.bool
    editableNode: React.PropTypes.object
    editableFocused: React.PropTypes.bool

  constructor: (@props) ->
    @state =
      toolbarTop: 0
      toolbarMode: "buttons"
      toolbarLeft: 0
      toolbarPos: "above"
      editAreaWidth: 9999 # This will get set on first selection
      toolbarVisible: false
      linkHoveringOver: null
    @_setToolbarState = _.debounce(@_setToolbarState, 10)
    @innerProps =
      links: []
      dragging: false
      selection: null
      doubleDown: false
      editableNode: null
      toolbarFocus: false
      editableFocused: null

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
  componentWillReceiveInnerProps: (nextInnerProps) =>
    @innerProps = _.extend @innerProps, nextInnerProps
    @fullProps = _.extend(@innerProps, @props)
    if "links" of nextInnerProps
      @_refreshLinkHoverListeners()
    @_setToolbarState()

  componentWillReceiveProps: (nextProps) =>
    @fullProps = _.extend(@innerProps, nextProps)
    @_setToolbarState()

  # The context menu, when activated, needs to make sure that the toolbar
  # is closed. Unfortunately, since there's no onClose callback for the
  # context menu, we can't hook up a reliable declarative state to the
  # menu. We break our declarative pattern in this one case.
  forceClose: ->
    @setState toolbarVisible: false

  render: ->
    <FloatingToolbar
      ref="floatingToolbar"
      top={@state.toolbarTop}
      left={@state.toolbarLeft}
      pos={@state.toolbarPos}
      mode={@state.toolbarMode}
      visible={@state.toolbarVisible}
      onSaveUrl={@props.onSaveUrl}
      onMouseEnter={@_onEnterToolbar}
      onChangeMode={@_onChangeMode}
      onMouseLeave={@_onLeaveToolbar}
      onDomMutator={@props.onDomMutator}
      linkToModify={@state.linkToModify}
      onChangeFocus={@_onChangeFocus}
      contentPadding={@CONTENT_PADDING}
      editAreaWidth={@state.editAreaWidth} />

  _onChangeFocus: (focus) =>
    @componentWillReceiveInnerProps toolbarFocus: focus

  _onChangeMode: (mode) =>
    if mode is "buttons"
      @componentWillReceiveInnerProps linkHoveringOver: null
      @setState
        toolbarMode: mode
        toolbarVisible: false
    else
      @setState toolbarMode: mode

  # We want the toolbar's state to be declaratively defined from other
  # states.
  _setToolbarState: =>
    props = @fullProps ? {}

    return if props.dragging or (props.doubleDown and not @state.toolbarVisible)

    if props.toolbarFocus
      @setState toolbarVisible: true
      return

    if @_shouldHideToolbar(props)
      @setState
        toolbarVisible: false
        toolbarMode: "buttons"
      return

    if props.linkHoveringOver
      url = props.linkHoveringOver.getAttribute('href')
      rect = props.linkHoveringOver.getBoundingClientRect()
      [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(rect)
      @setState
        toolbarVisible: true
        toolbarMode: "edit-link"
        toolbarTop: top
        toolbarLeft: left
        toolbarPos: toolbarPos
        linkToModify: props.linkHoveringOver
        editAreaWidth: editAreaWidth
    else
      # return if @state.toolbarMode is "edit-link"
      rect = DOMUtils.getRangeInScope(props.editableNode)?.getBoundingClientRect()
      if not rect or DOMUtils.isEmptyBoudingRect(rect)
        @setState
          toolbarVisible: false
          toolbarMode: "buttons"
      else
        [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(rect)
        @setState
          toolbarVisible: true
          toolbarTop: top
          toolbarLeft: left
          toolbarPos: toolbarPos
          linkToModify: null
          editAreaWidth: editAreaWidth

  _shouldHideToolbar: (props) ->
    return false if @state.toolbarMode is "edit-link"
    return false if props.linkHoveringOver
    return not props.editableFocused or
           not props.selection or
           props.selection.isCollapsed

  _refreshLinkHoverListeners: ->
    @_teardownLinkHoverListeners()
    @_links = {}
    links = Array.prototype.slice.call(@innerProps.links)
    links.forEach (link) =>
      link.hoverId = Utils.generateTempId()
      @_links[link.hoverId] = {}

      context = this
      enterListener = (event) ->
        link = this
        context._onEnterLink.call(context, link, event)
      leaveListener = (event) ->
        link = this
        context._onLeaveLink.call(context, link, event)

      link.addEventListener "mouseenter", enterListener
      link.addEventListener "mouseleave", leaveListener
      @_links[link.hoverId].link = link
      @_links[link.hoverId].enterListener = enterListener
      @_links[link.hoverId].leaveListener = leaveListener

  _onEnterLink: (link, event) =>
    HOVER_IN_DELAY = 250
    @_clearLinkTimeouts()
    @_links[link.hoverId].enterTimeout = setTimeout =>
      @componentWillReceiveInnerProps linkHoveringOver: link
    , HOVER_IN_DELAY

  _onLeaveLink: (link, event) =>
    HOVER_OUT_DELAY = 500
    @_clearLinkTimeouts()
    @_links[link.hoverId].leaveTimeout = setTimeout =>
      @componentWillReceiveInnerProps linkHoveringOver: null
    , HOVER_OUT_DELAY

  _onEnterToolbar: (event) =>
    clearTimeout(@_clearTooltipTimeout) if @_clearTooltipTimeout?

    # 1. Hover over a link until the toolbar appears.
    # 2. The toolbar's link input will be UNfocused
    # 3. Moving the mouse off the link and over the toolbar will cause
    # _onLinkLeave to fire. Before the `leaveTimeout` fires, clear it
    # since our mouse has safely made it to the tooltip.
    @_clearLinkTimeouts()

  # Called when the mouse leaves the "edit-link" mode toolbar.
  #
  # NOTE: The leave callback does NOT get called if the user has the input
  # field focused. We don't want the make the box dissapear under the user
  # when they're typing.
  _onLeaveToolbar: (event) =>
    HOVER_OUT_DELAY = 250
    @_clearTooltipTimeout = setTimeout =>
      # If we've hovered over a link until the toolbar appeared, then
      # `linkHoverOver` will be set to that link. When we move the mouse
      # onto the toolbar, `_onEnterToolbar` will make sure that
      # `linkHoveringOver` doesn't get cleared. If we then move our mouse
      # off of the toolbar, we need to remember to clear the hovering
      # link.
      @componentWillReceiveInnerProps linkHoveringOver: null
    , 250

  _clearLinkTimeouts: ->
    for hoverId, linkData of @_links
      clearTimeout(linkData.enterTimeout) if linkData.enterTimeout?
      clearTimeout(linkData.leaveTimeout) if linkData.leaveTimeout?

  _teardownLinkHoverListeners: =>
    for hoverId, linkData of @_links
      clearTimeout linkData.enterTimeout
      clearTimeout linkData.leaveTimeout
      linkData.link.removeEventListener "mouseenter", linkData.enterListener
      linkData.link.removeEventListener "mouseleave", linkData.leaveListener
    @_links = {}

  CONTENT_PADDING: 15

  _getToolbarPos: (referenceRect) =>
    return [0,0,0,0] unless @innerProps.editableNode

    TOP_PADDING = 10

    BORDER_RADIUS_PADDING = 15

    editArea = @innerProps.editableNode.getBoundingClientRect()

    calcLeft = (referenceRect.left - editArea.left) + referenceRect.width/2
    calcLeft = Math.min(Math.max(calcLeft, @CONTENT_PADDING+BORDER_RADIUS_PADDING), editArea.width - BORDER_RADIUS_PADDING)

    calcTop = referenceRect.top - editArea.top - 48
    toolbarPos = "above"
    if calcTop < TOP_PADDING
      calcTop = referenceRect.top - editArea.top + referenceRect.height + TOP_PADDING + 4
      toolbarPos = "below"

    return [calcLeft, calcTop, editArea.width, toolbarPos]

  _focusedOnToolbar: =>
    React.findDOMNode(@refs.floatingToolbar)?.contains(document.activeElement)

module.exports = FloatingToolbarContainer
