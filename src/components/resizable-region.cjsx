React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry} = require "inbox-exports"

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


module.exports = 
ResizableRegion = React.createClass
  displayName: 'ResizableRegion'

  propTypes:
    className: React.PropTypes.string
    handle: React.PropTypes.object.isRequired
    onResize: React.PropTypes.func

    initialWidth: React.PropTypes.number
    minWidth: React.PropTypes.number
    maxWidth: React.PropTypes.number

    initialHeight: React.PropTypes.number
    minHeight: React.PropTypes.number
    maxHeight: React.PropTypes.number

  getDefaultProps: ->
    handle: ResizableHandle.Right

  getInitialState: ->
    dragging: false

  render: ->
    if @props.handle.axis is 'horizontal'
      containerStyle =
        'minWidth': @props.minWidth
        'maxWidth': @props.maxWidth
        'position': 'relative'
        'height': '100%'

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

    <div className={@props.className} style={containerStyle}>
      {@props.children}
      <div className={@props.handle.className}
           onMouseDown={@_mouseDown}><div></div>
      </div>
    </div>

  componentDidUpdate: (lastProps, lastState) ->
    if lastState.dragging and not @state.dragging
      document.removeEventListener('mousemove', @_mouseMove)
      document.removeEventListener('mouseup', @_mouseUp)
    else if not lastState.dragging and @state.dragging
      document.addEventListener('mousemove', @_mouseMove)
      document.addEventListener('mouseup', @_mouseUp)

  componentWillReceiveProps: (nextProps) ->
    if nextProps.handle.axis is 'vertical' and nextProps.initialHeight != @props.initialHeight
      @setState(height: nextProps.initialHeight)
    if nextProps.handle.axis is 'horizontal' and nextProps.initialWidth != @props.initialWidth
      @setState(width: nextProps.initialWidth)

  _mouseDown: (event) ->
    return if event.button != 0
    bcr = @getDOMNode().getBoundingClientRect()
    @setState
      dragging: true
      bcr: bcr
    event.stopPropagation()
    event.preventDefault()

  _mouseUp: (event) ->
    return if event.button != 0
    @setState
      dragging: false
    @props.onResize(@state.height ? @state.width) if @props.onResize
    event.stopPropagation()
    event.preventDefault()

  _mouseMove: (event) ->
    return if !@state.dragging
    @setState @props.handle.transform(@state, @props, event)
    event.stopPropagation()
    event.preventDefault()

ResizableRegion.Handle = ResizableHandle
