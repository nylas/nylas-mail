_ = require "underscore-plus"
React = require "react"

positions =
  top:
    transform: (state, event) ->
      height: state.bcr.bottom - Math.max(5, event.pageY)
    cursor: "ns-resize"
  bottom:
    transform: (state, event) ->
      height: Math.max(state.initialHeight, event.pageY - state.bcr.top)
    cursor: "ns-resize"
  left:
    transform: (state, event) ->
      width: Math.max(5, state.bcr.right - event.pageX)
    cursor: "ew-resize"
  right:
    transform: (state, event) ->
      width: Math.max(5, - state.bcr.left + event.pageX)
    cursor: "ew-resize"

module.exports = ResizableComponent =
React.createClass
  displayName: 'ResizableComponent'
  propTypes:
    position: React.PropTypes.string
    onResize: React.PropTypes.func

  render: ->
    position = @props?.position ? 'top'
    h =  @state.height ? @props.initialHeight
    style = _.extend({}, @props.style ? {}, {height: h, width: @state.width})
    <div style={style} className="resizable">
      <div className={"resizeBar " + position} ref="resizeBar" style={@props.barStyle ? {}}/>
      {@props.children}
    </div>

  getInitialState: ->
    dragging: off

  componentDidMount: ->
    @refs.resizeBar.getDOMNode().addEventListener('mousedown', @_mouseDown)

  componentWillReceiveProps: (nextProps) ->
    if nextProps.initialHeight != @props.initialHeight
      @setState(height: nextProps.initialHeight)

  position: ->
    positions[@props?.position ? 'top']

  componentWillUnmount: ->
    @refs.resizeBar.getDOMNode().removeEventListener('mousedown', @_mouseDown)

  componentDidUpdate: (lastProps, lastState) ->
    if lastState.dragging && !@state.dragging
      document.body.style.cursor = ""
      document.removeEventListener('mousemove', @_mouseMove)
      document.removeEventListener('mouseup', @_mouseUp)
    else if !lastState.dragging && @state.dragging
      document.body.style.cursor = @position().cursor
      document.addEventListener('mousemove', @_mouseMove)
      document.addEventListener('mouseup', @_mouseUp)

  _mouseDown: (event) ->
    return if event.button != 0
    bcr = @getDOMNode().getBoundingClientRect()
    @setState
      dragging: on
      initialHeight: @state.initialHeight ? bcr.height
      bcr: bcr
    event.stopPropagation()
    event.preventDefault()

  _mouseUp: (event) ->
    return if event.button != 0
    @setState
      dragging: off
    @props.onResize(@state.height) if @props.onResize
    event.stopPropagation()
    event.preventDefault()

  _mouseMove: (event) ->
    return if !@state.dragging
    @setState @position().transform(@state, event)
    event.stopPropagation()
    event.preventDefault()
