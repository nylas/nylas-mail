# Utils for testing.
CSON = require 'season'
KeymapManager = require 'atom-keymap'

NylasTestUtils =
  loadKeymap: (keymapPath) ->
    {resourcePath} = NylasEnv.getLoadSettings()
    basePath = CSON.resolve("#{resourcePath}/keymaps/base")
    NylasEnv.keymaps.loadKeymap(basePath)

    if keymapPath?
      keymapPath = CSON.resolve("#{resourcePath}/#{keymapPath}")
      NylasEnv.keymaps.loadKeymap(keymapPath)

  keyPress: (key, target) ->
    # React's "renderIntoDocument" does not /actually/ attach the component
    # to the document. It's a sham: http://dragon.ak.fbcdn.net/hphotos-ak-xpf1/t39.3284-6/10956909_1423563877937976_838415501_n.js
    # The Atom keymap manager doesn't work correctly on elements outside of the
    # DOM tree, so we need to attach it.
    unless document.contains(target)
      parent = target
      while parent.parentNode?
        parent = parent.parentNode
      document.documentElement.appendChild(parent)

    event = KeymapManager.buildKeydownEvent(key, target: target)
    NylasEnv.keymaps.handleKeyboardEvent(event)

module.exports = NylasTestUtils
