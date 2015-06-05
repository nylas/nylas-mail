_ = require 'underscore'
React = require 'react/addons'
{Utils} = require 'nylas-exports'
classNames = require 'classnames'

###
The ScrollRegion component attaches a custom scrollbar.
###

class ScrollRegion extends React.Component
  @displayName: "ScrollRegion"

  @propTypes:
    onScroll: React.PropTypes.func
    className: React.PropTypes.string
    scrollTooltipComponent: React.PropTypes.func

  constructor: (@props) ->
    @state =
      totalHeight:0
      viewportHeight: 0
      viewportOffset: 0
      dragging: false
      scrolling: false

    Object.defineProperty(@, 'scrollTop', {
      get: -> React.findDOMNode(@refs.content).scrollTop
      set: (val) -> React.findDOMNode(@refs.content).scrollTop = val
    })

  componentDidMount: =>
    @_recomputeDimensions()

  componentDidUpdate: =>
    @_recomputeDimensions()

  componentWillUnmount: =>
    @_onHandleUp()

  shouldComponentUpdate: (newProps, newState) =>
    not Utils.isEqualReact(newProps, @props) or not Utils.isEqualReact(newState, @state)

  render: =>
    containerClasses =  "#{@props.className ? ''} " + classNames
      'scroll-region': true
      'dragging': @state.dragging
      'scrolling': @state.scrolling

    otherProps = _.omit(@props, _.keys(@constructor.propTypes))

    tooltip = []
    if @props.scrollTooltipComponent
      tooltip = <@props.scrollTooltipComponent viewportCenter={@state.viewportOffset + @state.viewportHeight / 2} totalHeight={@state.totalHeight} />

    <div className={containerClasses} {...otherProps}>
      <div className="scrollbar-track" style={@_scrollbarWrapStyles()} onMouseEnter={@_recomputeDimensions}>
        <div className="scrollbar-track-inner" ref="track" onClick={@_onScrollJump}>
          <div className="scrollbar-handle" onMouseDown={@_onHandleDown} style={@_scrollbarHandleStyles()} ref="handle" onClick={@_onHandleClick} >
            <div className="tooltip">{tooltip}</div>
          </div>
        </div>
      </div>
      <div className="scroll-region-content" onScroll={@_onScroll} ref="content">
        {@props.children}
      </div>
    </div>

  _scrollbarWrapStyles: =>
    position:'absolute'
    top: 0
    bottom: 0
    right: 0
    zIndex: 2

  _scrollbarHandleStyles: =>
    handleHeight = @_getHandleHeight()
    handleTop = (@state.viewportOffset / (@state.totalHeight - @state.viewportHeight)) * (@state.trackHeight - handleHeight)

    position:'relative'
    height: handleHeight
    top: handleTop

  _getHandleHeight: =>
    Math.min(@state.totalHeight, Math.max(40, (@state.trackHeight / @state.totalHeight) * @state.trackHeight))

  _recomputeDimensions: =>
    return unless @refs.content

    contentNode = React.findDOMNode(@refs.content)
    trackNode = React.findDOMNode(@refs.track)

    totalHeight = contentNode.scrollHeight
    trackHeight = trackNode.clientHeight
    viewportHeight = contentNode.clientHeight
    viewportOffset = contentNode.scrollTop

    if @state.totalHeight != totalHeight or
       @state.trackHeight != trackHeight or
       @state.viewportOffset != viewportOffset or
       @state.viewportHeight != viewportHeight
      @setState({totalHeight, trackHeight, viewportOffset, viewportHeight})

  _onHandleDown: (event) =>
    handleNode = React.findDOMNode(@refs.handle)
    @_trackOffset = React.findDOMNode(@refs.track).getBoundingClientRect().top
    @_mouseOffsetWithinHandle = event.pageY - handleNode.getBoundingClientRect().top
    window.addEventListener("mousemove", @_onHandleMove)
    window.addEventListener("mouseup", @_onHandleUp)
    @setState(dragging: true)

  _onHandleMove: (event) =>
    trackY = event.pageY - @_trackOffset - @_mouseOffsetWithinHandle
    trackPxToViewportPx = (@state.totalHeight - @state.viewportHeight) / (@state.trackHeight - @_getHandleHeight())

    contentNode = React.findDOMNode(@refs.content)
    contentNode.scrollTop = trackY * trackPxToViewportPx

  _onHandleUp: (event) =>
    window.removeEventListener("mousemove", @_onHandleMove)
    window.removeEventListener("mouseup", @_onHandleUp)
    @setState(dragging: false)

  _onHandleClick: (event) =>
    # Avoid event propogating up to track
    event.stopPropagation()

  _onScrollJump: (event) =>
    @_mouseOffsetWithinHandle = @_getHandleHeight() / 2
    @_onHandleMove(event)

  _onScroll: (event) =>
    @_recomputeDimensions()
    @props.onScroll?(event)

    if not @state.scrolling
      @setState(scrolling: true)

    @_onStoppedScroll ?= _.debounce =>
      @setState(scrolling: false)
    , 250
    @_onStoppedScroll()


module.exports = ScrollRegion
