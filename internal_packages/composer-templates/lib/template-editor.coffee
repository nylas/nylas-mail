{DOMUtils, ContenteditableExtension} = require 'nylas-exports'

class TemplateEditor extends ContenteditableExtension


  @onContentChanged: ({editor}) ->

    # Run through and remove all code nodes that are invalid
    codeNodes = editor.rootNode.querySelectorAll("code.var.empty")
    for codeNode in codeNodes
      # remove any style that was added by contenteditable
      codeNode.removeAttribute("style")
      # grab the text content and the indexable text content
      text = codeNode.textContent
      indexText = DOMUtils.getIndexedTextContent(codeNode).map( ({text}) -> text ).join("")
      # unwrap any code nodes that don't start/end with {{}}, and any with line breaks inside
      if not text.startsWith("{{") or not text.endsWith("}}") or indexText.indexOf("\n")>-1
        editor.whilePreservingSelection ->
          DOMUtils.unwrapNode(codeNode)

    # Attempt to sanitize spans that are needlessly created by contenteditable
    for span in editor.rootNode.querySelectorAll("span")
      if not span.className
        editor.whilePreservingSelection ->
          DOMUtils.unwrapNode(span)

    # Find all {{}} and wrap them in code nodes if they aren't already
    # Regex finds any {{ <contents> }} that doesn't contain {, }, or \n
    # https://regex101.com/r/jF2oF4/1
    ranges = editor.regExpSelectorAll(/\{\{[^\n{}]*?\}\}/g)
    for range in ranges
      if not DOMUtils.isWrapped(range, "CODE")
        # Preserve the selection based on text index within the range matched by the regex
        selIndex = editor.getSelectionTextIndex(range)
        codeNode = DOMUtils.wrap(range,"CODE")
        codeNode.className = "var empty"
        codeNode.textContent = codeNode.textContent # Sets node contents to just its textContent, strips HTML
        if selIndex?
          editor.restoreSelectionByTextIndex(codeNode, selIndex.startIndex, selIndex.endIndex)


  @onKeyDown: ({editor}) ->
    # Look for all existing code tags that we may have added before,
    # and remove any that now have invalid content (don't start with {{ and
    # end with }} as well as any that wrap the current selection

    codeNodes = editor.rootNode.querySelectorAll("code.var.empty")
    for codeNode in codeNodes
      text = codeNode.textContent
      if not text.startsWith("{{") or not text.endsWith("}}") or DOMUtils.selectionStartsOrEndsIn(codeNode)
        editor.whilePreservingSelection ->
          DOMUtils.unwrapNode(codeNode)

module.exports = TemplateEditor
