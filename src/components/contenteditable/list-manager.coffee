_str = require 'underscore.string'
{DOMUtils, ContenteditableExtension} = require 'nylas-exports'

class ListManager extends ContenteditableExtension
  @onContentChanged: (editableNode, selection) ->
    if @_spaceEntered and @hasListStartSignature(selection)
      @createList(null, selection)

  @onKeyDown: (editableNode, selection, event) ->
    @_spaceEntered = event.key is " "
    if DOMUtils.isInList()
      if event.key is "Backspace" and DOMUtils.atStartOfList()
        event.preventDefault()
        @outdentListItem(selection)
      else if event.key is "Tab" and selection.isCollapsed
        event.preventDefault()
        if event.shiftKey
          @outdentListItem(selection)
        else
          document.execCommand("indent")
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

  @createList: (event, selection) ->
    text = selection.anchorNode?.textContent

    if @numberRegex().test(text)
      @originalInput = text[0...3]
      document.execCommand("insertOrderedList")
      @removeListStarter(@numberRegex(), selection)
    else if @bulletRegex().test(text)
      @originalInput = text[0...2]
      document.execCommand("insertUnorderedList")
      @removeListStarter(@bulletRegex(), selection)
    else
      return
    el = DOMUtils.closest(selection.anchorNode, "li")
    DOMUtils.Mutating.removeEmptyNodes(el)
    event?.preventDefault()

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
  @restoreOriginalInput: (selection) ->
    node = selection.anchorNode
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
      DOMUtils.Mutating.moveSelectionToIndexInAnchorNode(selection, 3) # digit plus dot
    if @bulletRegex().test(@originalInput)
      DOMUtils.Mutating.moveSelectionToIndexInAnchorNode(selection, 2) # dash or star

    @originalInput = null

  @outdentListItem: (selection) ->
    if @originalInput
      document.execCommand("outdent")
      @restoreOriginalInput(selection)
    else
      document.execCommand("outdent")

module.exports = ListManager
