React = require 'react'
_ = require "underscore-plus"

module.exports =
EventedIFrame = React.createClass
  displayName: 'EventedIFrame'

  render: ->
    <iframe seamless="seamless" {...@props} />

  componentDidMount: ->
    @_subscribeToIFrameEvents()

  componentWillUnmount: ->
    doc = @getDOMNode().contentDocument
    for e in ['click', 'keydown', 'mousedown', 'mousemove', 'mouseup']
      doc?.removeEventListener?(e)

  _subscribeToIFrameEvents: ->
    doc = @getDOMNode().contentDocument
    _.defer =>
      doc.addEventListener "click", @_onIFrameClick
      doc.addEventListener "keydown", @_onIFrameKeydown
      doc.addEventListener "mousedown", @_onIFrameMouseEvent
      doc.addEventListener "mousemove", @_onIFrameMouseEvent
      doc.addEventListener "mouseup", @_onIFrameMouseEvent

  # The iFrame captures events that take place over it, which causes some
  # interesting behaviors. For example, when you drag and release over the
  # iFrame, the mouseup never fires in the parent window.

  _onIFrameClick: (e) ->
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

  _onIFrameMouseEvent: (event) ->
    nodeRect = @getDOMNode().getBoundingClientRect()
    @getDOMNode().dispatchEvent(new MouseEvent(event.type, _.extend({}, event, {
      clientX: event.clientX + nodeRect.left
      clientY: event.clientY + nodeRect.top
      pageX: event.pageX + nodeRect.left
      pageY: event.pageY + nodeRect.top
    })))

  _onIFrameKeydown: (event) ->
    return if event.metaKey or event.altKey or event.ctrlKey
    @getDOMNode().dispatchEvent(new KeyboardEvent(event.type, event))
