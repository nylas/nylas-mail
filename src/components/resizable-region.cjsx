React = require 'react'
_ = require 'underscore-plus'
{Actions,
 ComponentRegistry,
 PriorityUICoordinator} = require "inbox-exports"

ResizableHandle =
  Top:
    axis: 'vertical'
    className: 'flexbox-handle-vertical flexbox-handle-top'
    transform: (state, props, event) ->
      'height': Math.min(props.maxHeight ? 10000, Math.max(props.minHeight ? 0, state.bcr.bottom - event.pageY))
  Bottom:
    axis: 'vertical'
    className: 'flexbox-handle-vertical flexbox-handle-bottom'
    transform: (state, props, event) ->
      'height': Math.min(props.maxHeight ? 10000, Math.max(props.minHeight ? 0, event.pageY - state.bcr.top))
  Left:
    axis: 'horizontal'
    className: 'flexbox-handle-horizontal flexbox-handle-left'
    transform: (state, props, event) ->
      'width': Math.min(props.maxWidth ? 10000, Math.max(props.minWidth ? 0, state.bcr.right - event.pageX))
  Right:
    axis: 'horizontal'
    className: 'flexbox-handle-horizontal flexbox-handle-right'
    transform: (state, props, event) ->
      'width': Math.min(props.maxWidth ? 10000, Math.max(props.minWidth ? 0, event.pageX - state.bcr.left))

###
Public: ResizableRegion wraps it's `children` in a div with a fixed width or height, and a
draggable edge. It is used throughout Nylas Mail to implement resizable columns, trays, etc.
###
class ResizableRegion extends React.Component
  @displayName = 'ResizableRegion'

  ###
  Public: React `props` supported by ResizableRegion:
  
   - `handle` Provide a {ResizableHandle} to indicate which edge of the
     region should be draggable.
   - `onResize` A {Function} that will be called continuously as the region is resized.
   - `initialWidth` (optional) Initial width, if the handle indicates a horizontal resizing axis.
   - `minWidth` (optional) Minimum width, if the handle indicates a horizontal resizing axis.
   - `maxWidth` (optional) Maximum width, if the handle indicates a horizontal resizing axis.
   - `initialHeight` (optional) Initial height, if the handle indicates a vertical resizing axis.
   - `minHeight` (optional) Minimum height, if the handle indicates a vertical resizing axis.
   - `maxHeight` (optional) Maximum height, if the handle indicates a vertical resizing axis.
  ###
  @propTypes =
    handle: React.PropTypes.object.isRequired
    onResize: React.PropTypes.func

    initialWidth: React.PropTypes.number
    minWidth: React.PropTypes.number
    maxWidth: React.PropTypes.number

    initialHeight: React.PropTypes.number
    minHeight: React.PropTypes.number
    maxHeight: React.PropTypes.number

  constructor: (@props = {}) ->
    @props.handle ?= ResizableHandle.Right
    @state =
      dragging: false

  render: =>
    if @props.handle.axis is 'horizontal'
      containerStyle =
        'minWidth': @props.minWidth
        'maxWidth': @props.maxWidth
        'position': 'relative'

      if @state.width?
        containerStyle.width = @state.width
      else
        containerStyle.flex = 1

    else
      containerStyle =
        'minHeight': @props.minHeight
        'maxHeight': @props.maxHeight
        'position': 'relative'
        'width': '100%'

      if @state.height?
        containerStyle.height = @state.height
      else if @props.initialHeight?
        containerStyle.height = @props.initialHeight
      else
        containerStyle.flex = 1

    otherProps = _.omit(@props, _.keys(@constructor.propTypes))
    
    <div style={containerStyle} {...otherProps}>
      {@props.children}
      <div className={@props.handle.className}
           onMouseDown={@_mouseDown}><div></div>
      </div>
    </div>

  componentDidUpdate: (lastProps, lastState) =>
    if lastState.dragging and not @state.dragging
      document.removeEventListener('mousemove', @_mouseMove)
      document.removeEventListener('mouseup', @_mouseUp)
    else if not lastState.dragging and @state.dragging
      document.addEventListener('mousemove', @_mouseMove)
      document.addEventListener('mouseup', @_mouseUp)

  componentWillReceiveProps: (nextProps) =>
    if nextProps.handle.axis is 'vertical' and nextProps.initialHeight != @props.initialHeight
      @setState(height: nextProps.initialHeight)
    if nextProps.handle.axis is 'horizontal' and nextProps.initialWidth != @props.initialWidth
      @setState(width: nextProps.initialWidth)
 
  componentWillUnmount: =>
    PriorityUICoordinator.endPriorityTask(@_taskId) if @_taskId
    @_taskId = null

  _mouseDown: (event) =>
    return if event.button != 0
    bcr = React.findDOMNode(@).getBoundingClientRect()
    @setState
      dragging: true
      bcr: bcr
    event.stopPropagation()
    event.preventDefault()

    PriorityUICoordinator.endPriorityTask(@_taskId) if @_taskId
    @_taskId = PriorityUICoordinator.beginPriorityTask()

  _mouseUp: (event) =>
    return if event.button != 0
    @setState
      dragging: false
    @props.onResize(@state.height ? @state.width) if @props.onResize
    event.stopPropagation()
    event.preventDefault()

    PriorityUICoordinator.endPriorityTask(@_taskId)
    @_taskId = null

  _mouseMove: (event) =>
    return if !@state.dragging
    @setState @props.handle.transform(@state, @props, event)
    @props.onResize(@state.height ? @state.width) if @props.onResize
    event.stopPropagation()
    event.preventDefault()

ResizableRegion.Handle = ResizableHandle

module.exports = ResizableRegion
