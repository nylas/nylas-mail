# Utils for testing.
CSON = require 'season'
React = require 'react/addons'
KeymapManager = require 'atom-keymap'
ReactTestUtils = React.addons.TestUtils

NylasTestUtils =
  loadKeymap: (keymapPath) ->
    {resourcePath} = NylasEnv.getLoadSettings()
    basePath = CSON.resolve("#{resourcePath}/keymaps/base")
    NylasEnv.keymaps.loadKeymap(basePath)

    if keymapPath?
      keymapPath = CSON.resolve("#{resourcePath}/#{keymapPath}")
      NylasEnv.keymaps.loadKeymap(keymapPath)

  keyDown: (key, target) ->
    event = KeymapManager.buildKeydownEvent(key, target: target)
    NylasEnv.keymaps.handleKeyboardEvent(event)

  # React's "renderIntoDocument" does not /actually/ attach the component
  # to the document. It's a sham: http://dragon.ak.fbcdn.net/hphotos-ak-xpf1/t39.3284-6/10956909_1423563877937976_838415501_n.js
  # The Atom keymap manager doesn't work correctly on elements outside of the
  # DOM tree, so we need to attach it.
  renderIntoDocument: (reactDOM) ->
    node = ReactTestUtils.renderIntoDocument(reactDOM)
    $node = React.findDOMNode(node)
    unless document.body.contains($node)
      parent = $node
      while parent.parentNode?
        parent = parent.parentNode
      document.body.appendChild(parent)
    return node

  removeFromDocument: (reactElement) ->
    $el = React.findDOMNode(reactElement)
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
