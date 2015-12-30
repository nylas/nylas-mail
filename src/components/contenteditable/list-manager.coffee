_str = require 'underscore.string'
{DOMUtils, ContenteditableExtension} = require 'nylas-exports'

class ListManager extends ContenteditableExtension
  @onContentChanged: ({editor, mutations}) ->
    if @_spaceEntered and @hasListStartSignature(editor.currentSelection())
      @createList(editor)

    @_collapseAdjacentLists(editor)

  @onKeyDown: ({editor, event}) ->
    @_spaceEntered = event.key is " "
    if DOMUtils.isInList()
      if event.key is "Backspace" and DOMUtils.atStartOfList()
        event.preventDefault()
        @outdentListItem(editor)
      else if event.key is "Tab" and editor.currentSelection().isCollapsed
        event.preventDefault()
        if event.shiftKey
          @outdentListItem(editor)
        else
          editor.indent()
      else
        # Do nothing, let the event through.
        @originalInput = null
    else
      @originalInput = null

    return event

  @bulletRegex: -> /^[*-]\s/

  @numberRegex: -> /^\d\.\s/

  @hasListStartSignature: (selection) ->
    return false unless selection?.anchorNode
    return false if not selection.isCollapsed

    text = selection.anchorNode.textContent
    return @numberRegex().test(text) or @bulletRegex().test(text)

  @createList: (editor) ->
    text = editor.currentSelection().anchorNode?.textContent

    if @numberRegex().test(text)
      @originalInput = text[0...3]
      editor.insertOrderedList()
      @removeListStarter(@numberRegex(), editor.currentSelection())
    else if @bulletRegex().test(text)
      @originalInput = text[0...2]
      editor.insertUnorderedList()
      @removeListStarter(@bulletRegex(), editor.currentSelection())
    else
      return
    el = DOMUtils.closest(editor.currentSelection().anchorNode, "li")
    DOMUtils.Mutating.removeEmptyNodes(el)

  @removeListStarter: (starterRegex, selection) ->
    el = DOMUtils.closest(selection.anchorNode, "li")
    textContent = el.textContent.replace(starterRegex, "")
    if textContent.trim().length is 0
      el.innerHTML = "<br>"
    else
      textNode = DOMUtils.findFirstTextNode(el)
      textNode.textContent = textNode.textContent.replace(starterRegex, "")

  # From a newly-created list
  # Outdent returns to a <div><br/></div> structure
  # I need to turn into <div>-&nbsp;</div>
  #
  # From a list with content
  # Outent returns to <div>sometext</div>
  # We need to turn that into <div>-&nbsp;sometext</div>
  @restoreOriginalInput: (editor) ->
    node = editor.currentSelection().anchorNode
    return unless node
    if node.nodeType is Node.TEXT_NODE
      node.textContent = @originalInput + node.textContent
    else if node.nodeType is Node.ELEMENT_NODE
      textNode = DOMUtils.findFirstTextNode(node)
      if not textNode
        node.innerHTML = @originalInput.replace(" ", "&nbsp;") + node.innerHTML
      else
        textNode.textContent = @originalInput + textNode.textContent

    if @numberRegex().test(@originalInput)
      DOMUtils.Mutating.moveSelectionToIndexInAnchorNode(editor.currentSelection(), 3) # digit plus dot
    if @bulletRegex().test(@originalInput)
      DOMUtils.Mutating.moveSelectionToIndexInAnchorNode(editor.currentSelection(), 2) # dash or star

    @originalInput = null

  @outdentListItem: (editor) ->
    if @originalInput
      editor.outdent()
      @restoreOriginalInput(editor)
    else
      editor.outdent()

  # If users ended up with two <ul> lists adjacent to each other, we
  # collapse them into one. We leave adjacent <ol> lists intact in case
  # the user wanted to restart the numbering sequence
  @_collapseAdjacentLists: (editor) ->
    els = editor.rootNode.querySelectorAll('ul, ol')

    # This mutates the DOM in place.
    DOMUtils.Mutating.collapseAdjacentElements(els)

module.exports = ListManager
