React = require 'react'
_ = require "underscore-plus"

###
Public: EventedIFrame is a thin wrapper around the DOM's standard `<iframe>` element.
You should always use EventedIFrame, because it provides important event hooks that
ensure keyboard and mouse events are properly delivered to the application when
fired within iFrames.

```
<div className="file-frame-container">
  <EventedIFrame src={src} />
  <Spinner visible={!@state.ready} />
</div>
```

Any `props` added to the <EventedIFrame> are passed to the iFrame it renders.

Section: Component Kit
###
class EventedIFrame extends React.Component
  @displayName = 'EventedIFrame'

  render: =>
    <iframe seamless="seamless" {...@props} />

  componentDidMount: =>
    @_subscribeToIFrameEvents()

  componentWillUnmount: =>
    doc = React.findDOMNode(@).contentDocument
    for e in ['click', 'keydown', 'mousedown', 'mousemove', 'mouseup']
      doc?.removeEventListener?(e)

  _subscribeToIFrameEvents: =>
    doc = React.findDOMNode(@).contentDocument
    _.defer =>
      doc.addEventListener "click", @_onIFrameClick
      doc.addEventListener "keydown", @_onIFrameKeydown
      doc.addEventListener "mousedown", @_onIFrameMouseEvent
      doc.addEventListener "mousemove", @_onIFrameMouseEvent
      doc.addEventListener "mouseup", @_onIFrameMouseEvent

  # The iFrame captures events that take place over it, which causes some
  # interesting behaviors. For example, when you drag and release over the
  # iFrame, the mouseup never fires in the parent window.

  _onIFrameClick: (e) =>
    e.preventDefault()
    e.stopPropagation()
    target = e.target

    # This lets us detect when we click an element inside of an <a> tag
    while target? and (target isnt document) and (target isnt window)
      if target.getAttribute('href')?
        atom.windowEventHandler.openLink target: target
        target = null
      else
        target = target.parentElement

  _onIFrameMouseEvent: (event) =>
    node = React.findDOMNode(@)
    nodeRect = node.getBoundingClientRect()
    node.dispatchEvent(new MouseEvent(event.type, _.extend({}, event, {
      clientX: event.clientX + nodeRect.left
      clientY: event.clientY + nodeRect.top
      pageX: event.pageX + nodeRect.left
      pageY: event.pageY + nodeRect.top
    })))

  _onIFrameKeydown: (event) =>
    return if event.metaKey or event.altKey or event.ctrlKey
    React.findDOMNode(@).dispatchEvent(new KeyboardEvent(event.type, event))


module.exports = EventedIFrame
