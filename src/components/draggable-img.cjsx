React = require 'react'

###
Public: Images are supposed to by default show a ghost image when dragging and
dropping. Unfortunately this does not work in Electron. Since we're a
desktop app we don't want all images draggable, but we do want some (like
attachments) to be able to be dragged away with a preview image.
###
class DraggableImg extends React.Component
  @displayName: 'DraggableImg'

  constructor: (@props) ->

  render: =>
    <img ref="img" draggable="true" onDragStart={@_onDragStart} {...@props} />

  _onDragStart: (event) =>
    img = React.findDOMNode(@refs.img)
    rect = img.getBoundingClientRect()
    y = event.clientY - rect.top
    x = event.clientX - rect.left
    event.dataTransfer.setDragImage(img, x, y)
    return

module.exports = DraggableImg
