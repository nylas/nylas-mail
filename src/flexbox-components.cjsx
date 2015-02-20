React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry} = require "inbox-exports"

FlexboxResizeHandlePosition =
  top:
    className: 'flexbox-handle-vertical flexbox-handle-top'
    transform: (state, props, event) ->
      'height': Math.max(state.initialHeight, state.bcr.bottom - Math.max(5, event.pageY))
  bottom:
    className: 'flexbox-handle-vertical flexbox-handle-bottom'
    transform: (state, props, event) ->
      'height': Math.max(state.initialHeight, event.pageY - state.bcr.top)
  left:
    className: 'flexbox-handle-horizontal flexbox-handle-left'
    transform: (state, props, event) ->
      'width': Math.min(props.maxWidth, Math.max(props.minWidth, state.bcr.right - event.pageX))
  right:
    className: 'flexbox-handle-horizontal flexbox-handle-right'
    transform: (state, props, event) ->
      'width': Math.min(props.maxWidth, Math.max(props.minWidth, event.pageX - state.bcr.left))


FlexboxResizableRegion = React.createClass
  displayName: 'FlexboxResizableRegion'

  propTypes:
    handlePosition: React.PropTypes.object.isRequired

  getDefaultProps: ->
    handlePosition: FlexboxResizeHandlePosition.right

  getInitialState: ->
    dragging: false

  render: ->
    containerStyle =
      'minWidth': @props.minWidth
      'maxWidth': @props.maxWidth
      'position': 'relative'
      'height': '100%'

    if @state.width?
      containerStyle.width = @state.width
    else
      containerStyle.flex = 1

    <div style={containerStyle}>
      {@props.children}
      <div className={@props.handlePosition.className}
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
    event.stopPropagation()
    event.preventDefault()

  _mouseMove: (event) ->
    return if !@state.dragging
    @setState @props.handlePosition.transform(@state, @props, event)
    event.stopPropagation()
    event.preventDefault()



Flexbox = React.createClass
  displayName: 'Flexbox'
  propTypes:
    name: React.PropTypes.string
    direction: React.PropTypes.string
    style: React.PropTypes.object

  render: ->
    style = _.extend (@props.style || {}),
      'flexDirection': @props.direction,
      'display': 'flex'
      'height':'100%'

    <div name={name} style={style}>
      {@props.children}
    </div>


module.exports =
  Flexbox: Flexbox
  FlexboxResizableRegion: FlexboxResizableRegion
  FlexboxResizeHandlePosition: FlexboxResizeHandlePosition
