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
    event = KeymapManager.buildKeydownEvent(key, target: target)
    NylasEnv.keymaps.handleKeyboardEvent(event)

module.exports = NylasTestUtils
