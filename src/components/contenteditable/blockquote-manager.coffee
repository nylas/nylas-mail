{DOMUtils, ContenteditableExtension} = require 'nylas-exports'

class BlockquoteManager extends ContenteditableExtension
  @onKeyDown: ({editor, event}) ->
    if event.key is "Backspace"
      if @_isInBlockquote(editor) and @_isAtStartOfLine(editor)
        editor.outdent()
        event.preventDefault()

  @_isInBlockquote: (editor) ->
    sel = editor.currentSelection()
    return unless sel.isCollapsed
    DOMUtils.closest(sel.anchorNode, "blockquote")?

  @_isAtStartOfLine: (editor) ->
    sel = editor.currentSelection()
    return false unless sel.anchorNode
    return false unless sel.isCollapsed
    return false unless sel.anchorOffset is 0

    return @_ancestorRelativeLooksLikeBlock(sel.anchorNode)

  @_ancestorRelativeLooksLikeBlock: (node) ->
    return true if DOMUtils.looksLikeBlockElement(node)
    sibling = node
    while sibling = sibling.previousSibling
      if DOMUtils.looksLikeBlockElement(sibling)
        return true

      if DOMUtils.looksLikeNonEmptyNode(sibling)
        return false

    # never found block level element
    return @_ancestorRelativeLooksLikeBlock(node.parentNode)

module.exports = BlockquoteManager
