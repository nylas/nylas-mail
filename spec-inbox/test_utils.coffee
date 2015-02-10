# Utils for testing.
CSON = require 'season'
KeymapManager = require 'atom-keymap'

InboxTestUtils =
  loadKeymap: (keymapPath) ->
    baseKeymaps = CSON.readFileSync("keymaps/base.cson")
    atom.keymaps.add("keymaps/base.cson", baseKeymaps)

    if keymapPath?
      keymapFile = CSON.readFileSync(keymapPath)
      atom.keymaps.add(keymapPath, keymapFile)

  keyPress: (key, target) ->
    event = KeymapManager.buildKeydownEvent(key, target: target)
    document.dispatchEvent(event)

module.exports = InboxTestUtils

