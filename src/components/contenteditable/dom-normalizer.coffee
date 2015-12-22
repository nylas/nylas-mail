{ContenteditableExtension, DOMUtils} = require 'nylas-exports'

class DOMNormalizer extends ContenteditableExtension

  # This component works by re-rendering on every change and restoring the
  # selection. This is also how standard React controlled inputs work too.
  #
  # Since the contents of the contenteditable are complex, nested DOM
  # structures, a simple replacement of the DOM is not easy. There are a
  # variety of edge cases that we need to correct for and prepare both the
  # HTML and the selection to be serialized without error.
  @onContentChanged: (editor, mutations) ->
    @_cleanHTML(editor)
    @_cleanSelection(editor)

  # We need to clean the HTML on input to fix several edge cases that
  # arise when we go to save the selection state and restore it on the
  # next render.
  @_cleanHTML: (editor) ->
    return unless editor.rootNode

    # One issue is that we need to pre-normalize the HTML so it looks the
    # same after it gets re-inserted. If we key selection markers off of
    # an non normalized DOM, then they won't match up when the HTML gets
    # reset.
    #
    # The Node.normalize() method puts the specified node and all of its
    # sub-tree into a "normalized" form. In a normalized sub-tree, no text
    # nodes in the sub-tree are empty and there are no adjacent text
    # nodes.
    editor.normalize()

    @_fixLeadingBRCondition(editor)

  # An issue arises from <br/> tags immediately inside of divs. In this
  # case the cursor's anchor node will not be the <br/> tag, but rather
  # the entire enclosing element. Sometimes, that enclosing element is the
  # container wrapping all of the content. The browser has a native
  # built-in feature that will automatically scroll the page to the bottom
  # of the current element that the cursor is in if the cursor is off the
  # screen. In the given case, that element is the whole div. The net
  # effect is that the browser will scroll erroneously to the bottom of
  # the whole content div, which is likely NOT where the cursor is or the
  # user wants. The solution to this is to replace this particular case
  # with <span></span> tags and place the cursor in there.
  @_fixLeadingBRCondition: (editor) ->
    treeWalker = document.createTreeWalker editor.rootNode
    while treeWalker.nextNode()
      currentNode = treeWalker.currentNode
      if @_hasLeadingBRCondition(currentNode)
        newNode = document.createElement("div")
        newNode.appendChild(document.createElement("br"))
        currentNode.replaceChild(newNode, currentNode.childNodes[0])
    return

  @_hasLeadingBRCondition: (node) ->
    childNodes = node.childNodes
    return childNodes.length >= 2 and childNodes[0].nodeName is "BR"

  # After an input, the selection can sometimes get itself into a state
  # that either can't be restored properly, or will cause undersirable
  # native behavior. This method, in combination with `_cleanHTML`, fixes
  # each of those scenarios before we save and later restore the
  # selection.
  @_cleanSelection: (editor) ->
    selection = editor.currentSelection()
    return unless selection.anchorNode? and selection.focusNode?

    # The _unselectableNode case only is valid when it's at the very top
    # (offset 0) of the node. If the offsets are > 0 that means we're
    # trying to select somewhere within some sort of containing element.
    # This is okay to do. The odd case only arises at the top of
    # unselectable elements.
    return if selection.anchorOffset > 0 or selection.focusOffset > 0

    if selection.isCollapsed and @_unselectableNode(selection.focusNode)
      treeWalker = document.createTreeWalker(selection.focusNode)
      while treeWalker.nextNode()
        currentNode = treeWalker.currentNode
        if @_unselectableNode(currentNode)
          selection.setBaseAndExtent(currentNode, 0, currentNode, 0)
          break
    return

  @_unselectableNode: (node) ->
    return true if not node
    if node.nodeType is Node.TEXT_NODE and DOMUtils.isBlankTextNode(node)
      return true
    else if node.nodeType is Node.ELEMENT_NODE
      child = node.firstChild
      return true if not child
      hasText = (child.nodeType is Node.TEXT_NODE and not DOMUtils.isBlankTextNode(node))
      hasBr = (child.nodeType is Node.ELEMENT_NODE and node.nodeName is "BR")
      return not hasText and not hasBr

    else return false

module.exports = DOMNormalizer
