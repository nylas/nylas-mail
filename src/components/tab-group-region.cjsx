React = require 'react'
ReactDOM = require 'react-dom'

class TabGroupRegion extends React.Component
  @childContextTypes:
    parentTabGroup: React.PropTypes.object

  _onKeyDown: (event) =>
    if event.key is "Tab" and not event.defaultPrevented
      dir = if event.shiftKey then -1 else 1
      @shiftFocus(dir)
      event.preventDefault()
      event.stopPropagation()
    return

  shiftFocus: (dir) =>
    nodes = ReactDOM.findDOMNode(@).querySelectorAll('input, [contenteditable], [tabIndex]')
    current = document.activeElement
    idx = Array.from(nodes).indexOf(current)

    for i in [0..nodes.length]
      idx = idx + dir
      if idx < 0
        idx = nodes.length - 1
      else
        idx = idx % nodes.length

      continue if nodes[idx].tabIndex is -1
      nodes[idx].focus()
      if nodes[idx].nodeName is 'INPUT' and nodes[idx].type is "text"
        nodes[idx].setSelectionRange(nodes[idx].value.length, nodes[idx].value.length)
      return

  getChildContext: =>
    parentTabGroup: @

  render: ->
    <div {...@props} onKeyDown={@_onKeyDown}>{@props.children}</div>

module.exports = TabGroupRegion
