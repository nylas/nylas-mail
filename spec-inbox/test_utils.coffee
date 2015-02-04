# Utils for testing.
KeymapManager = require 'atom-keymap'

InboxTestUtils =
  keyPress: (key, target) ->
    event = KeymapManager.keydownEvent(key, target: target)
    document.dispatchEvent(event)

module.exports = InboxTestUtils

