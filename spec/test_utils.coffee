# Utils for testing.
CSON = require 'season'
KeymapManager = require 'atom-keymap'

NylasTestUtils =
  loadKeymap: (keymapPath) ->
    {resourcePath} = atom.getLoadSettings()
    basePath = CSON.resolve("#{resourcePath}/keymaps/base")
    baseKeymaps = CSON.readFileSync(basePath)
    atom.keymaps.add(basePath, baseKeymaps)

    if keymapPath?
      keymapPath = CSON.resolve("#{resourcePath}/#{keymapPath}")
      keymapFile = CSON.readFileSync(keymapPath)
      atom.keymaps.add(keymapPath, keymapFile)

  keyPress: (key, target) ->
    event = KeymapManager.buildKeydownEvent(key, target: target)
    document.dispatchEvent(event)

module.exports = NylasTestUtils
