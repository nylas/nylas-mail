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

    # Attempt to sanitize extra nodes that may have been created by contenteditable on certain text editing
    # operations (insertion/deletion of line breaks, etc.). These are generally <span>, but can also be
    # <font>, <b>, and possibly others. The extra nodes often grab CSS styles from neighboring elements
    # as inline style, including the yellow text from <code> nodes that we insert. This is contenteditable
    # trying to be "smart" and preserve styles, which is very undesirable for the <code> node styles. The
    # below code is a hack to prevent yellow text from appearing.
    for node in editor.rootNode.querySelectorAll("*")
      if not node.className and node.style.color == "#c79b11"
        editor.whilePreservingSelection ->
          DOMUtils.unwrapNode(node)

    for node in editor.rootNode.querySelectorAll("font")
      if node.color == "#c79b11"
        editor.whilePreservingSelection ->
          DOMUtils.unwrapNode(node)

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


module.exports = TemplateEditor
