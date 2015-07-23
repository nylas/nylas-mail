React = require 'react'
_ = require 'underscore'

class DropZone extends React.Component
  @propTypes:
    shouldAcceptDrop: React.PropTypes.func.isRequired
    onDrop: React.PropTypes.func.isRequired
    onDragStateChange: React.PropTypes.func

  constructor: ->

  render: ->
    otherProps = _.omit(@props, _.keys(@constructor.propTypes))
    <div {...otherProps} onDragEnter={@_onDragEnter} onDragLeave={@_onDragLeave} onDrop={@_onDrop}>
      {@props.children}
    </div>

  # We maintain a "dragCounter" because dragEnter and dragLeave events *stack*
  # when the user moves the item in and out of DOM elements inside of our container.
  # It's really awful and everyone hates it.
  #
  # Alternative solution *maybe* is to set pointer-events:none; during drag.

  _onDragEnter: (e) =>
    return unless @props.shouldAcceptDrop(e)
    @_dragCounter ?= 0
    @_dragCounter += 1
    if @_dragCounter is 1 and @props.onDragStateChange
      @props.onDragStateChange(isDropping: true)
    return

  _onDragLeave: (e) =>
    return unless @props.shouldAcceptDrop(e)
    @_dragCounter -= 1
    if @_dragCounter is 0 and @props.onDragStateChange
      @props.onDragStateChange(isDropping: false)
    return

  _onDrop: (e) =>
    return unless @props.shouldAcceptDrop(e)
    if @props.onDragStateChange
      @props.onDragStateChange(isDropping: false)
    @_dragCounter = 0
    @props.onDrop(e)
    return

module.exports = DropZone
