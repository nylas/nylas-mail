{DOMUtils, ContenteditableExtension} = require 'nylas-exports'

class TabManager extends ContenteditableExtension
  @onKeyDown: ({editor, event}) ->
    # This is a special case where we don't want to bubble up the event to
    # the keymap manager if the extension prevented the default behavior
    if event.defaultPrevented
      event.stopPropagation()
      return

    if event.key is "Tab"
      @_onTabDownDefaultBehavior(editor, event)
      return

  @_onTabDownDefaultBehavior: (editor, event) ->
    selection = editor.currentSelection()
    if selection?.isCollapsed
      if event.shiftKey
        if DOMUtils.isAtTabChar(selection)
          @_removeLastCharacter(editor)
        else if DOMUtils.isAtBeginningOfDocument(editor.rootNode, selection)
          return # Don't stop propagation
      else
        editor.insertText("\t")
    else
      if event.shiftKey
        editor.insertText("")
      else
        editor.insertText("\t")
    event.preventDefault()
    event.stopPropagation()

  @_removeLastCharacter: (editor) ->
    if DOMUtils.isSelectionInTextNode(editor.currentSelection())
      node = editor.currentSelection().anchorNode
      offset = editor.currentSelection().anchorOffset
      editor.currentSelection().setBaseAndExtent(node, offset - 1, node, offset)
      editor.delete()

module.exports = TabManager
