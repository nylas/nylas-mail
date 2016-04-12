_ = require 'underscore'
React = require 'react'
ReactDOM = require 'react-dom'
{Utils} = require 'nylas-exports'
classNames = require 'classnames'
ScrollbarTicks = require './scrollbar-ticks'

class Scrollbar extends React.Component
  @displayName: 'Scrollbar'
  @propTypes:
    scrollTooltipComponent: React.PropTypes.func
    # A scrollbarTickProvider is any object that has the `listen` and
    # `scrollbarTicks` method. Since ScrollRegions tend to encompass large
    # render trees it's more efficent for the scrollbar to listen for its
    # own state then have it passed down as new props and potentially
    # cause re-renders of the whole scroll region. The `scrollbarTicks`
    # method must return an array of numbers between 0 and 1 which
    # represent the height percentages at which tick marks will be
    # rendered.
    scrollbarTickProvider: React.PropTypes.object
    getScrollRegion: React.PropTypes.func

  constructor: (@props) ->
    @state =
      totalHeight: 0
      trackHeight: 0
      viewportHeight: 0
      viewportScrollTop: 0
      dragging: false
      scrolling: false
      scrollbarTicks: []

  componentDidMount: ->
    if @props.scrollbarTickProvider?.listen
      @_tickUnsub = @props.scrollbarTickProvider.listen(@_onTickProviderChange)

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentWillUnmount: =>
    @_onHandleUp({preventDefault: -> })
    @_tickUnsub?()

  setStateFromScrollRegion: (state) ->
    @setState(state)

  render: ->
    containerClasses = classNames
      'scrollbar-track': true
      'dragging': @state.dragging
      'scrolling': @state.scrolling
      'with-ticks': @state.scrollbarTicks.length > 0

    tooltip = []
    if @props.scrollTooltipComponent and @state.dragging
      tooltip = <@props.scrollTooltipComponent viewportCenter={@state.viewportScrollTop + @state.viewportHeight / 2} totalHeight={@state.totalHeight} />

    <div className={containerClasses} style={@_scrollbarWrapStyles()} onMouseEnter={@recomputeDimensions}>
      <div className="scrollbar-track-inner" ref="track" onClick={@_onScrollJump}>
        {@_renderScrollbarTicks()}
        <div className="scrollbar-handle" onMouseDown={@_onHandleDown} style={@_scrollbarHandleStyles()} ref="handle" onClick={@_onHandleClick} >
          <div className="tooltip">{tooltip}</div>
        </div>
      </div>
    </div>

  recomputeDimensions: (options = {}) =>
    if @props.getScrollRegion?
      @props.getScrollRegion()._recomputeDimensions(options)
    @_recomputeDimensions(options)

  _onTickProviderChange: =>
    if not @props.scrollbarTickProvider?.scrollbarTicks
      throw new Error("The scrollbarTickProvider must implement `scrollbarTicks`")
    @setState scrollbarTicks: @props.scrollbarTickProvider.scrollbarTicks()

  _renderScrollbarTicks: ->
    return false unless @state.scrollbarTicks.length > 0
    <ScrollbarTicks ticks={@state.scrollbarTicks}/>

  _recomputeDimensions: ({useCachedValues}) =>
    if not useCachedValues
      trackNode = ReactDOM.findDOMNode(@refs.track)
      return unless trackNode
      trackHeight = trackNode.clientHeight
      if trackHeight isnt @state.trackHeight
        @setState({trackHeight})

  _scrollbarHandleStyles: =>
    handleHeight = @_getHandleHeight()
    handleTop = (@state.viewportScrollTop / (@state.totalHeight - @state.viewportHeight)) * (@state.trackHeight - handleHeight)

    position:'relative'
    height: handleHeight || 0
    top: handleTop || 0

  _scrollbarWrapStyles: =>
    position:'absolute'
    top: 0
    bottom: 0
    right: 0
    zIndex: 2
    visibility: "hidden" if @state.totalHeight != 0 && @state.totalHeight == @state.viewportHeight

  _onHandleDown: (event) =>
    handleNode = ReactDOM.findDOMNode(@refs.handle)
    @_trackOffset = ReactDOM.findDOMNode(@refs.track).getBoundingClientRect().top
    @_mouseOffsetWithinHandle = event.pageY - handleNode.getBoundingClientRect().top
    window.addEventListener("mousemove", @_onHandleMove)
    window.addEventListener("mouseup", @_onHandleUp)
    @setState(dragging: true)
    event.preventDefault()

  _onHandleMove: (event) =>
    trackY = event.pageY - @_trackOffset - @_mouseOffsetWithinHandle
    trackPxToViewportPx = (@state.totalHeight - @state.viewportHeight) / (@state.trackHeight - @_getHandleHeight())
    @props.getScrollRegion().scrollTop = trackY * trackPxToViewportPx
    event.preventDefault()

  _onHandleUp: (event) =>
    window.removeEventListener("mousemove", @_onHandleMove)
    window.removeEventListener("mouseup", @_onHandleUp)
    @setState(dragging: false)
    event.preventDefault()

  _onHandleClick: (event) =>
    # Avoid event propogating up to track
    event.stopPropagation()

  _onScrollJump: (event) =>
    @_trackOffset = ReactDOM.findDOMNode(@refs.track).getBoundingClientRect().top
    @_mouseOffsetWithinHandle = @_getHandleHeight() / 2
    @_onHandleMove(event)

  _getHandleHeight: =>
    Math.min(@state.totalHeight, Math.max(40, (@state.trackHeight / @state.totalHeight) * @state.trackHeight))


###
The ScrollRegion component attaches a custom scrollbar.
###
class ScrollRegion extends React.Component
  @displayName: "ScrollRegion"

  @propTypes:
    onScroll: React.PropTypes.func
    onScrollEnd: React.PropTypes.func
    className: React.PropTypes.string
    scrollTooltipComponent: React.PropTypes.func
    scrollbarTickProvider: React.PropTypes.object
    children: React.PropTypes.oneOfType([React.PropTypes.element, React.PropTypes.array])
    getScrollbar: React.PropTypes.func

  # Concept from https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UITableView_Class/#//apple_ref/c/tdef/UITableViewScrollPosition

  @ScrollPosition:
    # Scroll so that the desired region is at the top of the viewport
    Top: 'Top'
    # Scroll so that the desired region is at the bottom of the viewport
    Bottom: 'Bottom'
    # Scroll so that the desired region is visible in the viewport, with the
    # least movement possible.
    Visible: 'Visible'
    # Scroll so that the desired region is centered in the viewport
    Center: 'Center'
    # Scroll so that the desired region is centered in the viewport, only if it
    # is currently not visible
    CenterIfInvisible: 'CenterIfInvisible'

  constructor: (@props) ->
    @_scrollToTaskId = 0
    @_scrollbarComponent = null
    @state =
      totalHeight:0
      viewportHeight: 0
      viewportScrollTop: 0
      scrolling: false

    Object.defineProperty(@, 'scrollTop', {
      get: -> ReactDOM.findDOMNode(@refs.content).scrollTop
      set: (val) -> ReactDOM.findDOMNode(@refs.content).scrollTop = val
    })

  componentDidMount: =>
    @_mounted = true
    @recomputeDimensions()

    @_heightObserver = new MutationObserver (mutations) =>
      recompute = false
      mutations.forEach (mutation) ->
        recompute ||= !mutation.oldValue or mutation.oldValue.indexOf('height:') isnt -1
      @recomputeDimensions({useCachedValues: false}) if recompute

    @_heightObserver.observe(ReactDOM.findDOMNode(@refs.content), {
      subtree: true,
      attributes: true,
      attributeOldValue: true,
      attributeFilter: ['style']
    })

  componentDidUpdate: (prevProps, prevState) =>
    if not @state.scrolling and @props.children isnt prevProps.children
      @recomputeDimensions()

  componentWillReceiveProps: (props) =>
    if @shouldInvalidateScrollbarComponent(props)
      @_scrollbarComponent = null

  componentWillUnmount: =>
    @_heightObserver.disconnect()
    @_mounted = false

  shouldComponentUpdate: (newProps, newState) =>
    # Because this component renders @props.children, it needs to update
    # on props.children changes. Unfortunately, computing isEqual on the
    # @props.children tree extremely expensive. Just let React's algorithm do it's work.
    true

  shouldInvalidateScrollbarComponent: (newProps) =>
    return true if newProps.scrollTooltipComponent isnt @props.scrollTooltipComponent
    return true if newProps.getScrollbar isnt @props.getScrollbar
    return false

  render: =>
    containerClasses =  "#{@props.className ? ''} " + classNames
      'scroll-region': true
      'dragging': @state.dragging
      'scrolling': @state.scrolling

    if not @props.getScrollbar
      @_scrollbarComponent ?= <Scrollbar
        ref="scrollbar"
        scrollbarTickProvider={@props.scrollbarTickProvider}
        scrollTooltipComponent={@props.scrollTooltipComponent}
        getScrollRegion={@_getSelf} />

    otherProps = Utils.fastOmit(@props, Object.keys(@constructor.propTypes))

    <div className={containerClasses} {...otherProps}>
      {@_scrollbarComponent}
      <div className="scroll-region-content" onScroll={@_onScroll} ref="content">
        <div className="scroll-region-content-inner">
          {@props.children}
        </div>
      </div>
    </div>

  # Public: Scroll to the DOM Node provided.
  #
  scrollTo: (node, {position, settle, done} = {}) =>
    if node instanceof React.Component
      node = ReactDOM.findDOMNode(node)
    unless node instanceof Node
      throw new Error("ScrollRegion.scrollTo: requires a DOM node or React element. Maybe you meant scrollToRect?")
    @_scroll {position, settle, done}, =>
      node.getBoundingClientRect()

  # Public: Scroll to the client rectangle provided. Note: This method expects
  # a ClientRect or similar object with top, left, width, height relative to the
  # window, not the scroll region. This is designed to make it easy to use with
  # node.getBoundingClientRect()
  scrollToRect: (rect, {position, settle, done} = {}) ->
    if rect instanceof Node
      throw new Error("ScrollRegion.scrollToRect: requires a rect. Maybe you meant scrollTo?")
    if not rect.top? or not rect.height?
      throw new Error("ScrollRegion.scrollToRect: requires a rect with `top` and `height` attributes.")
    @_scroll {position, settle, done}, => rect

  _scroll: ({position, settle, done}, clientRectProviderCallback) ->
    contentNode = ReactDOM.findDOMNode(@refs.content)
    position ?= ScrollRegion.ScrollPosition.Visible

    if settle is true
      settleFn = @_settleHeight
    else
      settleFn = (callback) -> callback()

    @_scrollToTaskId += 1
    taskId = @_scrollToTaskId

    settleFn =>
      # If another scroll call has been made since ours, don't do anything.
      return done?(false) unless @_scrollToTaskId is taskId

      contentClientRect = contentNode.getBoundingClientRect()
      rect = _.clone(clientRectProviderCallback())

      # For sanity's sake, convert the client rectangle we get into a rect
      # relative to the contentRect of our scroll region.
      rect.top = rect.top - contentClientRect.top + contentNode.scrollTop
      rect.bottom = rect.bottom - contentClientRect.top + contentNode.scrollTop

      # Also give ourselves a representation of the visible region, in the same
      # coordinate space as `rect`
      contentVisibleRect = _.clone(contentClientRect)
      contentVisibleRect.top += contentNode.scrollTop
      contentVisibleRect.bottom += contentNode.scrollTop

      if position is ScrollRegion.ScrollPosition.Top
        @scrollTop = rect.top
      else if position is ScrollRegion.ScrollPosition.Bottom
        @scrollTop = (rect.top + rect.height) - contentClientRect.height
      else if position is ScrollRegion.ScrollPosition.Center
        @scrollTop = rect.top - (contentClientRect.height - rect.height) / 2
      else if position is ScrollRegion.ScrollPosition.CenterIfInvisible
        if not Utils.rectVisibleInRect(rect, contentVisibleRect)
          @scrollTop = rect.top - (contentClientRect.height - rect.height) / 2
      else if position is ScrollRegion.ScrollPosition.Visible
        distanceBelowBottom = (rect.top + rect.height) - (contentClientRect.height + contentNode.scrollTop)
        distanceAboveTop = @scrollTop - rect.top
        if distanceBelowBottom >= 0
          @scrollTop += distanceBelowBottom
        else if distanceAboveTop >= 0
          @scrollTop -= distanceAboveTop

      done?(true)

  _settleHeight: (callback) =>
    contentNode = ReactDOM.findDOMNode(@refs.content)
    lastContentHeight = -1
    scrollIfSettled = =>
      return unless @_mounted
      contentRect = contentNode.getBoundingClientRect()
      if contentRect.height isnt lastContentHeight
        lastContentHeight = contentRect.height
      else
        return callback()
      window.requestAnimationFrame(scrollIfSettled)
    scrollIfSettled()

  recomputeDimensions: (options = {}) =>
    scrollbar = @props.getScrollbar?() ? @refs.scrollbar
    scrollbar._recomputeDimensions(options) if scrollbar
    @_recomputeDimensions(options)

  _recomputeDimensions: ({useCachedValues}) =>
    return unless @refs.content
    contentNode = ReactDOM.findDOMNode(@refs.content)
    return unless contentNode

    viewportScrollTop = contentNode.scrollTop

    # While we're scrolling, calls to contentNode.scrollHeight / clientHeight
    # force the browser to immediately flush any DOM changes and compute the
    # height of the node. This hurts performance and also kind of unnecessary,
    # since it's unlikely these values will change while scrolling.
    if useCachedValues
      totalHeight = @state.totalHeight ? contentNode.scrollHeight
      trackHeight = @state.trackHeight ? contentNode.scrollHeight
      viewportHeight = @state.viewportHeight ? contentNode.clientHeight
    else
      totalHeight = contentNode.scrollHeight
      viewportHeight = contentNode.clientHeight

    if @state.totalHeight != totalHeight or
       @state.viewportHeight != viewportHeight or
       @state.viewportScrollTop != viewportScrollTop
      @_setSharedState({totalHeight, viewportScrollTop, viewportHeight})

  _setSharedState: (state) ->
    scrollbar = @props.getScrollbar?() ? @refs.scrollbar
    if scrollbar
      scrollbar.setStateFromScrollRegion(state)
    @setState(state)

  _onScroll: (event) =>
    # onScroll events propogate, which is a bit strange. We could actually be
    # receiving a scroll event for a textarea inside the scroll region.
    # See Preferences > Signatures > textarea
    return unless event.target is ReactDOM.findDOMNode(@refs.content)

    if @state.scrolling
      @recomputeDimensions({useCachedValues: true})
    else
      @recomputeDimensions()
      @_setSharedState(scrolling: true)

    @props.onScroll?(event)

    @_onScrollEnd ?= _.debounce =>
      @_setSharedState(scrolling: false)
      @recomputeDimensions()
      @props.onScrollEnd?(event)
    , 250
    @_onScrollEnd()

  _getSelf: =>
    @


ScrollRegion.Scrollbar = Scrollbar

module.exports = ScrollRegion
