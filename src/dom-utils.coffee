_ = require 'underscore'
_s = require 'underscore.string'

DOMUtils =
  Mutating:
    replaceFirstListItem: (li, replaceWith) ->
      list = DOMUtils.closest(li, "ul, ol")

      if replaceWith.length is 0
        replaceWith = replaceWith.replace /\s/g, "&nbsp;"
        text = document.createElement("div")
        text.innerHTML = "<br>"
      else
        replaceWith = replaceWith.replace /\s/g, "&nbsp;"
        text = document.createElement("span")
        text.innerHTML = "#{replaceWith}"

      if list.querySelectorAll('li').length <= 1
        # Delete the whole list and replace with text
        list.parentNode.replaceChild(text, list)
      else
        # Delete the list item and prepend the text before the rest of the
        # list
        li.parentNode.removeChild(li)
        list.parentNode.insertBefore(text, list)

      child = text.childNodes[0] ? text
      index = Math.max(replaceWith.length - 1, 0)
      selection = document.getSelection()
      selection.setBaseAndExtent(child, index, child, index)

    removeEmptyNodes: (node) ->
      Array::slice.call(node.childNodes).forEach (child) ->
        if child.textContent is ''
          node.removeChild(child)
        else
          DOMUtils.Mutating.removeEmptyNodes(child)

    # Given a bunch of elements, it will go through and find all elements
    # that are adjacent to that one of the same type. For each set of
    # adjacent elements, it will put all children of those elements into
    # the first one and delete the remaining elements.
    collapseAdjacentElements: (els=[]) ->
      return if els.length is 0
      els = Array::slice.call(els)

      seenEls = []
      toMerge = []

      for el in els
        continue if el in seenEls
        adjacent = DOMUtils.collectAdjacent(el)
        seenEls = seenEls.concat(adjacent)
        continue if adjacent.length <= 1
        toMerge.push(adjacent)

      anchors = []
      for mergeSet in toMerge
        anchor = mergeSet[0]
        remaining = mergeSet[1..-1]
        for el in remaining
          while (el.childNodes.length > 0)
            anchor.appendChild(el.childNodes[0])
        DOMUtils.Mutating.removeElements(remaining)
        anchors.push(anchor)

      return anchors

    removeElements: (elements=[]) ->
      for el in elements
        try
          if el.parentNode then el.parentNode.removeChild(el)
        catch
          # This can happen if we've already removed ourselves from the
          # node or it no longer exists
          continue
      return elements

    applyTextInRange: (range, selection, newText) ->
      range.deleteContents()
      node = document.createTextNode(newText)
      range.insertNode(node)
      range.selectNode(node)
      selection.removeAllRanges()
      selection.addRange(range)

    getRangeAtAndSelectWord: (selection, index) ->
      range = selection.getRangeAt(index)

      # On Windows, right-clicking a word does not select it at the OS-level.
      if range.collapsed
        DOMUtils.Mutating.selectWordContainingRange(range)
        range = selection.getRangeAt(index)
      return range

    # This method finds the bounding points of the word that the range
    # is currently within and selects that word.
    selectWordContainingRange: (range) ->
      selection = document.getSelection()
      node = selection.focusNode
      text = node.textContent
      wordStart = _s.reverse(text.substring(0, selection.focusOffset)).search(/\s/)
      if wordStart is -1
        wordStart = 0
      else
        wordStart = selection.focusOffset - wordStart
      wordEnd = text.substring(selection.focusOffset).search(/\s/)
      if wordEnd is -1
        wordEnd = text.length
      else
        wordEnd += selection.focusOffset

      selection.removeAllRanges()
      range = new Range()
      range.setStart(node, wordStart)
      range.setEnd(node, wordEnd)
      selection.addRange(range)

    moveSelectionToIndexInAnchorNode: (selection, index) ->
      return unless selection.isCollapsed
      node = selection.anchorNode
      selection.setBaseAndExtent(node, index, node, index)

    moveSelectionToEnd: (selection) ->
      return unless selection.isCollapsed
      node = DOMUtils.findLastTextNode(selection.anchorNode)
      index = node.length
      selection.setBaseAndExtent(node, index, node, index)

  getSelectionRectFromDOM: (selection) ->
    selection ?= document.getSelection()
    node = selection.anchorNode
    if node.nodeType is Node.TEXT_NODE
      r = document.createRange()
      r.selectNodeContents(node)
      return r.getBoundingClientRect()
    else if node.nodeType is Node.ELEMENT_NODE
      return node.getBoundingClientRect()
    else
      return null

  isSelectionInTextNode: (selection) ->
    selection ?= document.getSelection()
    return false unless selection
    return selection.isCollapsed and selection.anchorNode.nodeType is Node.TEXT_NODE and selection.anchorOffset > 0

  isAtTabChar: (selection) ->
    selection ?= document.getSelection()
    if DOMUtils.isSelectionInTextNode(selection)
      return selection.anchorNode.textContent[selection.anchorOffset - 1] is "\t"
    else return false

  isAtBeginningOfDocument: (dom, selection) ->
    selection ?= document.getSelection()
    return false if not selection.isCollapsed
    return false if selection.anchorOffset > 0
    return true if dom.childNodes.length is 0
    return true if selection.anchorNode is dom
    firstChild = dom.childNodes[0]
    return selection.anchorNode is firstChild

  atStartOfList: ->
    selection = document.getSelection()
    anchor = selection.anchorNode
    return false if not selection.isCollapsed
    return true if anchor?.nodeName is "LI"
    return false if selection.anchorOffset > 0
    li = DOMUtils.closest(anchor, "li")
    return unless li
    return DOMUtils.isFirstChild(li, anchor)

  # Selectors for input types
  inputTypes: -> "input, textarea, *[contenteditable]"

  # https://developer.mozilla.org/en-US/docs/Web/API/Element/closest
  # Only Elements (not Text nodes) have the `closest` method
  closest: (node, selector) ->
    if node instanceof HTMLElement
      return node.closest(selector)
    else if node?.parentNode
      return DOMUtils.closest(node.parentNode, selector)
    else return null

  closestAtCursor: (selector) ->
    selection = document.getSelection()
    return unless selection?.isCollapsed
    return DOMUtils.closest(selection.anchorNode, selector)

  closestElement: (node) ->
    if node instanceof HTMLElement
      return node
    else if node?.parentNode
      return DOMUtils.closestElement(node.parentNode)
    else return null

  isInList: ->
    li = DOMUtils.closestAtCursor("li")
    list = DOMUtils.closestAtCursor("ul, ol")
    return li and list

  # Returns an array of all immediately adjacent nodes of a particular
  # nodeName relative to the root. Includes the root if it has the correct
  # nodeName.
  #
  # nodName is optional. if left blank it'll be the nodeName of the root
  collectAdjacent: (root, nodeName) ->
    nodeName ?= root.nodeName
    adjacent = []

    node = root
    while node.nextSibling?.nodeName is nodeName
      adjacent.push(node.nextSibling)
      node = node.nextSibling

    if root.nodeName is nodeName
      adjacent.unshift(root)

    node = root
    while node.previousSibling?.nodeName is nodeName
      adjacent.unshift(node.previousSibling)
      node = node.previousSibling

    return adjacent

  getNodeIndex: (context, nodeToFind) =>
    DOMUtils.indexOfNodeInSimilarNodes(context, nodeToFind)

  getRangeInScope: (scope) =>
    selection = document.getSelection()
    return null if not DOMUtils.selectionInScope(selection, scope)
    try
      range = selection.getRangeAt(0)
    catch
      console.warn "Selection is not returning a range"
      return document.createRange()
    range

  selectionInScope: (selection, scope) ->
    return false if not selection?
    return false if not scope?
    return (scope.contains(selection.anchorNode) and
            scope.contains(selection.focusNode))

  isEmptyBoundingRect: (rect) ->
    rect.top is 0 and rect.bottom is 0 and rect.left is 0 and rect.right is 0

  atEndOfContent: (selection, rootScope, containerScope) ->
    containerScope ?= rootScope
    if selection.isCollapsed

      # We need to use `lastChild` instead of `lastElementChild` because
      # we need to eventually check if the `selection.focusNode`, which is
      # usually a TEXT node, is equal to the returned `lastChild`.
      # `lastElementChild` will not return TEXT nodes.
      #
      # Unfortunately, `lastChild` can sometime return COMMENT nodes and
      # other blank TEXT nodes that we don't want to compare to.
      #
      # For example, if you have the structure:
      # <div>
      #   <p>Foo</p>
      # </div>
      #
      # The div may have 2 childNodes and 1 childElementNode. The 2nd
      # hidden childNode is a TEXT node with a data of "\n". I actually
      # want to return the <p></p>.
      #
      # However, The <p> element may have 1 childNode and 0
      # childElementNodes. In that case I DO want to return the TEXT node
      # that has the data of "foo"
      lastChild = DOMUtils.lastNonBlankChildNode(containerScope)

      # Special case for a completely empty contenteditable.
      # In this case `lastChild` will be null, but we are definitely at
      # the end of the content.
      if containerScope is rootScope
        return true if containerScope.childNodes.length is 0

      return false unless lastChild

      # NOTE: `.contains` returns true if `lastChild` is equal to
      # `selection.focusNode`
      #
      # See: http://ejohn.org/blog/comparing-document-position/
      inLastChild = lastChild.contains(selection.focusNode)

      # We should do true object identity here instead of `.isEqualNode`
      isLastChild = lastChild is selection.focusNode

      if isLastChild
        if selection.focusNode?.length
          atEndIndex = selection.focusOffset is selection.focusNode.length
        else
          atEndIndex = selection.focusOffset is 0
        return atEndIndex
      else if inLastChild
        DOMUtils.atEndOfContent(selection, rootScope, lastChild)
      else return false

    else return false

  lastNonBlankChildNode: (node) ->
    lastNode = null
    for childNode in node.childNodes by -1
      if childNode.nodeType is Node.TEXT_NODE
        if DOMUtils.isBlankTextNode(childNode)
          continue
        else
          return childNode
      else if childNode.nodeType is Node.ELEMENT_NODE
        return childNode
      else continue
    return lastNode

  lastDescendent: (node) ->
    return null unless node
    if node.childNodes.length > 0
      return DOMUtils.lastNode(node.childNodes[node.childNodes.length - 1])
    else return null

  findLastTextNode: (node) ->
    return null unless node
    return node if node.nodeType is Node.TEXT_NODE
    for childNode in node.childNodes by -1
      if childNode.nodeType is Node.TEXT_NODE
        return childNode
      else if childNode.nodeType is Node.ELEMENT_NODE
        return DOMUtils.findLastTextNode(childNode)
      else continue
    return null

  # Only looks down node trees with one child for a text node.
  # Returns null if there's no single text node
  findOnlyChildTextNode: (node) ->
    return null unless node
    return node if node.nodeType is Node.TEXT_NODE
    return null if node.childNodes.length > 1
    return DOMUtils.findOnlyChildTextNode(node.childNodes[0])

  findFirstTextNode: (node) ->
    return null unless node
    return node if node.nodeType is Node.TEXT_NODE
    for childNode in node.childNodes
      if childNode.nodeType is Node.TEXT_NODE
        return childNode
      else if childNode.nodeType is Node.ELEMENT_NODE
        return DOMUtils.findFirstTextNode(childNode)
      else continue
    return null

  isBlankTextNode: (node) ->
    return if not node?.data
    # \u00a0 is &nbsp;
    node.data.replace(/\u00a0/g, "x").trim().length is 0

  indexOfNodeInSimilarNodes: (context, nodeToFind) ->
    if nodeToFind.isEqualNode(context)
      return 0

    treeWalker = document.createTreeWalker context
    idx = 0
    while treeWalker.nextNode()
      if treeWalker.currentNode.isEqualNode nodeToFind
        if treeWalker.currentNode.isSameNode nodeToFind
          return idx
        idx += 1

    return -1

  # This is an optimization of findSimilarNodes which avoids tons of extra work
  # scanning a large DOM if all we're going to do is get item at index [0]. It
  # returns once it has found the similar node at the index desired.
  findSimilarNodeAtIndex: (context, nodeToFind, desiredIdx) ->
    if desiredIdx is 0 and nodeToFind.isEqualNode(context)
      return context

    treeWalker = document.createTreeWalker context
    idx = 0
    while treeWalker.nextNode()
      if treeWalker.currentNode.isEqualNode nodeToFind
        return treeWalker.currentNode if desiredIdx is idx
        idx += 1

    return null

  findCharacter: (context, character) ->
    node = null
    index = null
    treeWalker = document.createTreeWalker(context, NodeFilter.SHOW_TEXT)
    while currentNode = treeWalker.nextNode()
      i = currentNode.data.indexOf(character)
      if i >= 0
        node = currentNode
        index = i
        break
    return {node, index}

  escapeHTMLCharacters: (text) ->
    map =
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#039;'
    text.replace /[&<>"']/g, (m) -> map[m]

  # Checks to see if a particular node is visible and any of its parents
  # are visible.
  #
  # WARNING. This is a fairly expensive operation and should be used
  # sparingly.
  nodeIsVisible: (node) ->
    while node and node.nodeType is Node.ELEMENT_NODE
      style = window.getComputedStyle(node)
      node = node.parentNode
      continue unless style?
      # NOTE: opacity must be soft ==
      if style.opacity is 0 or style.opacity is "0" or style.visibility is "hidden" or style.display is "none"
        return false
    return true

  # This checks for the `offsetParent` to be null. This will work for
  # hidden elements, but not if they are in a `position:fixed` container.
  #
  # It is less thorough then Utils.nodeIsVisible, but is ~16x faster!!
  # http://jsperf.com/check-hidden
  # http://stackoverflow.com/a/21696585/793472
  nodeIsLikelyVisible: (node) -> node.offsetParent isnt null

  # Finds all of the non blank node in a {Document} object or HTML string.
  #
  # - `elementOrHTML` a dom element or an HTML string. If passed a
  # string, it will use `DOMParser` to convert it into a DOM object.
  #
  # "Non blank" is defined as any node whose `textContent` returns a
  # whitespace string.
  #
  # It will also reject nodes we see are invisible due to basic CSS
  # properties.
  #
  # Returns an array of DOM Nodes
  nodesWithContent: (elementOrHTML) ->
    nodes = []
    if _.isString(elementOrHTML)
      domParser = new DOMParser()
      doc = domParser.parseFromString(elementOrHTML, "text/html")
      allNodes = doc.body.childNodes
    else if elementOrHTML?.childNodes
      allNodes = elementOrHTML.childNodes
    else return nodes

    # We need to check `childNodes` instead of `children` to look for
    # plain Text nodes.
    for node in allNodes by -1
      if node.nodeName is "IMG"
        nodes.unshift node

      # It's important to use `textContent` and NOT `innerText`.
      # `innerText` causes a full reflow on every call because it
      # calcaultes CSS styles to determine if the text is truly visible or
      # not. This utility method must NOT cause a reflow. We instead will
      # check for basic cases ourselves.
      if (node.textContent ? "").trim().length is 0
        continue

      if node.style?.opacity is 0 or node.style?.opacity is "0" or node.style?.visibility is "hidden" or node.style?.display is "none"
        continue

      nodes.unshift node

    # No nodes with content found!
    return nodes

  parents: (node) ->
    nodes = []
    nodes.unshift(node) while node = node.parentNode
    return nodes

  # Returns true if the node is the first child of the root, is the root,
  # or is the first child of the first child of the root, etc.
  isFirstChild: (root, node) ->
    return false unless root and node
    return true if root is node
    return false unless root.childNodes[0]
    return true if root.childNodes[0] is node
    return DOMUtils.isFirstChild(root.childNodes[0], node)

  commonAncestor: (nodes=[], parentFilter) ->
    return null if nodes.length is 0

    nodes = Array::slice.call(nodes)

    minDepth = Number.MAX_VALUE
    # Sometimes we can potentially have tons of REALLY deeply nested
    # nodes. Since we're looking for a common ancestor we can really speed
    # this up by keeping track of the min depth reached. We know that we
    # won't need to check past that.
    getParents = (node) ->
      parentNodes = [node]
      depth = 0
      while node = node.parentNode
        if parentFilter
          parentNodes.unshift(node) if parentFilter(node)
        else
          parentNodes.unshift(node)
        depth += 1
        if depth > minDepth then break
      minDepth = Math.min(minDepth, depth)
      return parentNodes

    # _.intersection will preserve the ordering of the parent node arrays.
    # parents are ordered top to bottom, so the last node is the most
    # specific common ancenstor
    _.last(_.intersection.apply(null, nodes.map(getParents)))

  scrollAdjustmentToMakeNodeVisibleInContainer: (node, container) ->
    return unless node
    nodeRect = node.getBoundingClientRect()
    containerRect = container.getBoundingClientRect()
    return @scrollAdjustmentToMakeRectVisibleInRect(nodeRect, containerRect)

  scrollAdjustmentToMakeRectVisibleInRect: (nodeRect, containerRect) ->
    distanceBelowBottom = (nodeRect.top + nodeRect.height) - (containerRect.top + containerRect.height)
    if distanceBelowBottom >= 0
      return distanceBelowBottom

    distanceAboveTop = containerRect.top - nodeRect.top
    if distanceAboveTop >= 0
      return -distanceAboveTop

    return 0

  # Produces a list of indexed text contained within a given node. Returns a
  # list of objects of the form:
  #   {start, end, node, text}
  #
  # The text being indexed is intended to approximate the rendered content visible
  # to the user. This includes the nodeValue of any text nodes, and "\n" for any
  # DIV or BR elements.
  getIndexedTextContent: (node) ->
    items = []
    treeWalker = document.createTreeWalker(node, NodeFilter.SHOW_ELEMENT + NodeFilter.SHOW_TEXT)
    position = 0
    while treeWalker.nextNode()
      node = treeWalker.currentNode
      if node.tagName is "BR" or node.nodeType is Node.TEXT_NODE or node.tagName is "DIV"
        text = if node.nodeType is Node.TEXT_NODE then node.nodeValue else "\n"
        item =
          start: position
          end: position + text.length
          node: node
          text: text
        items.push(item)
        position += text.length
    return items

  # Returns true if the inner range is fully contained within the outer range
  rangeInRange: (inner, outer) ->
    return outer.isPointInRange(inner.startContainer, inner.startOffset) and outer.isPointInRange(inner.endContainer, inner.endOffset)

  # Returns true if the given ranges overlap
  rangeOverlapsRange: (range1, range2) ->
    return range2.isPointInRange(range1.startContainer, range1.startOffset) or range1.isPointInRange(range2.startContainer, range2.startOffset)

  # Returns true if the first range starts or ends within the second range.
  # Unlike rangeOverlapsRange, returns false if range2 is fully within range1.
  rangeStartsOrEndsInRange: (range1, range2) ->
    return range2.isPointInRange(range1.startContainer, range1.startOffset) or range2.isPointInRange(range1.endContainer, range1.endOffset)

  # Accepts a Range or a Node, and returns true if the current selection starts
  # or ends within it. Useful for knowing if a DOM modification will break the
  # current selection.
  selectionStartsOrEndsIn: (rangeOrNode) ->
    selection = document.getSelection()
    return false unless (selection and selection.rangeCount>0)
    if rangeOrNode instanceof Range
      return @rangeStartsOrEndsInRange(selection.getRangeAt(0), rangeOrNode)
    else if rangeOrNode instanceof Node
      range = new Range()
      range.selectNode(rangeOrNode)
      return @rangeStartsOrEndsInRange(selection.getRangeAt(0), range)
    else
      return false

  # Accepts a Range or a Node, and returns true if the current selection is fully
  # contained within it.
  selectionIsWithin: (rangeOrNode) ->
    selection = document.getSelection()
    return false unless (selection and selection.rangeCount>0)
    if rangeOrNode instanceof Range
      return @rangeInRange(selection.getRangeAt(0), rangeOrNode)
    else if rangeOrNode instanceof Node
      range = new Range()
      range.selectNode(rangeOrNode)
      return @rangeInRange(selection.getRangeAt(0), range)
    else
      return false

  # Finds all matches to a regex within a node's text content (including line
  # breaks from DIVs and BRs, as \n), and returns a list of corresponding Range
  # objects.
  regExpSelectorAll: (node, regex) ->

    # Generate a text representation of the node's content
    nodeTextList = @getIndexedTextContent(node)
    text = nodeTextList.map( ({text}) -> text ).join("")

    # Build a list of range objects by looping over regex matches in the
    # text content string, and then finding the node those match indexes
    # point to.
    ranges = []
    listPosition = 0
    while (result = regex.exec(text)) isnt null
      from = result.index
      to = regex.lastIndex
      item = nodeTextList[listPosition]
      range = document.createRange()

      while from >= item.end
        item = nodeTextList[++listPosition]
      start = if item.node.nodeType is Node.TEXT_NODE then from - item.start else 0
      range.setStart(item.node,start)

      while to > item.end
        item = nodeTextList[++listPosition]
      end = if item.node.nodeType is Node.TEXT_NODE then to - item.start else 0
      range.setEnd(item.node, end)

      ranges.push(range)

    return ranges

  # Returns true if the given range is the sole content of a node with the given
  # nodeName. If the range's parent has a different nodeName or contains any other
  # content, returns false.
  isWrapped: (range, nodeName) ->
    return false unless range and nodeName
    startNode = range.startContainer
    endNode = range.endContainer
    return false unless startNode.parentNode is endNode.parentNode # must have same parent
    return false if startNode.previousSibling or endNode.nextSibling # selection must span all sibling nodes
    return false if range.startOffset > 0 or range.endOffset < endNode.textContent.length # selection must span all text
    return startNode.parentNode.nodeName is nodeName

  # Modifies the DOM to wrap the given range with a new node, of name nodeName.
  #
  # If the range starts or ends in the middle of an node, that node will be split.
  # This will likely break selections that contain any of the affected nodes.
  wrap: (range, nodeName) ->
    newNode = document.createElement(nodeName)
    try
      range.surroundContents(newNode)
    catch
      newNode.appendChild(range.extractContents())
      range.insertNode(newNode)
    return newNode

  # Modifies the DOM to "unwrap" a given node, replacing that node with its contents.
  # This may break selections containing the affected nodes.
  # We don't use `document.createFragment` because the returned `fragment`
  # would be empty and useless after its children get replaced.
  unwrapNode: (node) ->
    return node if node.childNodes.length is 0
    replacedNodes = []
    parent = node.parentNode
    return node if not parent?

    lastChild = _.last(node.childNodes)
    replacedNodes.unshift(lastChild)
    parent.replaceChild(lastChild, node)

    while child = _.last(node.childNodes)
      replacedNodes.unshift(child)
      parent.insertBefore(child, lastChild)
      lastChild = child

    return replacedNodes

  isDescendantOf: (node, matcher = -> false) ->
    parent = node?.parentElement
    while parent
      return true if matcher(parent)
      parent = parent.parentElement
    false

  looksLikeBlockElement: (node) ->
    return node.nodeName in ["BR", "P", "BLOCKQUOTE", "DIV", "TABLE"]

  # When detecting if we're at the start of a "visible" line, we need to look
  # for text nodes that have visible content in them.
  looksLikeNonEmptyNode: (node) ->
    textNode = DOMUtils.findFirstTextNode(node)
    if textNode
      if /^[\n ]*$/.test(textNode.data)
        return false
      else return true
    else
      return false

  previousTextNode: (node) ->
    curNode = node
    while curNode.parentNode
      if curNode.previousSibling
        return this.findLastTextNode(curNode.previousSibling)
      curNode = curNode.parentNode
    return null

module.exports = DOMUtils
