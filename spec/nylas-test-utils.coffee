# Utils for testing.
React = require 'react'
ReactDOM = require 'react-dom'
ReactTestUtils = require('react-addons-test-utils')

NylasTestUtils =

  loadKeymap: (path) =>
    NylasEnv.keymaps.loadKeymap(path)

  simulateCommand: (target, command) =>
    target.dispatchEvent(new CustomEvent(command, {bubbles: true}))

  # React's "renderIntoDocument" does not /actually/ attach the component
  # to the document. It's a sham: http://dragon.ak.fbcdn.net/hphotos-ak-xpf1/t39.3284-6/10956909_1423563877937976_838415501_n.js
  # The Atom keymap manager doesn't work correctly on elements outside of the
  # DOM tree, so we need to attach it.
  renderIntoDocument: (component) ->
    node = ReactTestUtils.renderIntoDocument(component)
    $node = ReactDOM.findDOMNode(node)
    unless document.body.contains($node)
      parent = $node
      while parent.parentNode?
        parent = parent.parentNode
      document.body.appendChild(parent)
    return node

  removeFromDocument: (reactElement) ->
    $el = ReactDOM.findDOMNode(reactElement)
    if document.body.contains($el)
      for child in Array::slice.call(document.body.childNodes)
        if child.contains($el)
          document.body.removeChild(child)
          return

  # Returns mock observable that triggers immediately and provides helper
  # function to trigger later
  mockObservable: (data, {dispose} = {}) ->
    dispose ?= ->
    func = ->
    return {
      subscribe: (fn) ->
        func = fn
        func(data)
        return {dispose}
      triggerNext: (nextData = data) ->
        func(nextData)
    }

module.exports = NylasTestUtils
