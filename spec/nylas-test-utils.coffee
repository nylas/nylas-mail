# Utils for testing.
CSON = require 'season'
KeymapManager = require 'atom-keymap'

NylasTestUtils =
  loadKeymap: (keymapPath) ->
    {resourcePath} = atom.getLoadSettings()
    basePath = CSON.resolve("#{resourcePath}/keymaps/base")
    atom.keymaps.loadKeymap(basePath)

    if keymapPath?
      keymapPath = CSON.resolve("#{resourcePath}/#{keymapPath}")
      atom.keymaps.loadKeymap(keymapPath)

  keyPress: (key, target) ->
    event = KeymapManager.buildKeydownEvent(key, target: target)
    atom.keymaps.handleKeyboardEvent(event)

module.exports = NylasTestUtils
