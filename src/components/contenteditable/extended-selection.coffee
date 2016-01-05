_ = require 'underscore'
{DOMUtils} = require 'nylas-exports'
ExportedSelection = require './exported-selection'

# Convenience methods over the DOM's Selection object
# https://developer.mozilla.org/en-US/docs/Web/API/Selection
class ExtendedSelection
  constructor: (@scopeNode) ->
    @scopeNode ?= document.body
    @rawSelection = document.getSelection()

  isInScope: ->
    @anchorNode? and
    @focusNode? and
    @anchorOffset? and
    @focusOffset? and
    @scopeNode.contains(@anchorNode) and
    @scopeNode.contains(@focusNode)

  select: (args...) ->
    if args.length is 0
      throw @_errBadUsage()
    else if args.length is 1
      if args[0] instanceof ExportedSelection
        @importSelection(args[0])
      else if args[0] instanceof Range
        @selectRange(args[0])
      else
        @selectAt(args[0])
    else if args.length is 2
      @selectFromTo(args...)
    else if args.length is 3
      throw @_errBadUsage()
    else if args.length is 4
      @selectFromToWithIndex(args...)
    else if args.length >= 5
      throw @_errBadUsage()

  selectAt: (at) ->
    nodeAt = @findNodeAt(at)
    @setBaseAndExtent(nodeAt, 0, nodeAt, (nodeAt.length ? 0))

  selectRange: (range) ->
    @setBaseAndExtent(range.startContainer, range.startOffset, range.endContainer, range.endOffset)

  selectFromTo: (from, to) ->
    fromNode = @findNodeAt(from)
    toNode = @findNodeAt(to)
    @setBaseAndExtent(fromNode, 0, toNode, (toNode.length ? 0))

  selectFromToWithIndex: (from, fromIndex, to, toIndex) ->
    fromNode = @findNodeAt(from)
    toNode = @findNodeAt(to)
    if (not _.isNumber(fromIndex)) or (not _.isNumber(toIndex))
      throw @_errBadUsage()
    @setBaseAndExtent(fromNode, fromIndex, toNode, toIndex)

  exportSelection: -> new ExportedSelection(@rawSelection, @scopeNode)

  # Since the last time we exported the selection, the DOM may have
  # completely changed due to a re-render. To the user it may look
  # identical, but the newly rendered region may be comprised of
  # completely new DOM nodes. Our old node references may not exist
  # anymore. As such, we have the task of re-finding the nodes again and
  # creating a new selection that matches as accurately as possible.
  #
  # There are multiple ways of setting a new selection with the Selection
  # API. One very common one is to create a new Range object and then call
  # `addRange` on a selection instance. This does NOT work for us because
  # `Range` objects are direction-less. A Selection's start node (aka
  # anchor node aka base node) can be "after" a selection's end node (aka
  # focus node aka extent node).
  importSelection: (exportedSelection) ->
    return unless exportedSelection instanceof ExportedSelection
    newAnchorNode = DOMUtils.findSimilarNodes(@scopeNode, exportedSelection.anchorNode)[exportedSelection.anchorNodeIndex]

    newFocusNode = DOMUtils.findSimilarNodes(@scopeNode, exportedSelection.focusNode)[exportedSelection.focusNodeIndex]

    @setBaseAndExtent(newAnchorNode,
                      exportedSelection.anchorOffset,
                      newFocusNode,
                      exportedSelection.focusOffset)

  findNodeAt: (arg) ->
    if arg instanceof Node
      return arg
    else if _.isString(arg)
      return @scopeNode.querySelector(arg)
    else if _.isRegExp(arg)
      ## TODO
      DOMUtils.findNodeByRegex(@scopeNode, arg)
      return

  # Finds the start and end text index of the current selection relative
  # to a given Node or Range. Returns an object of the form:
  #   {startIndex, endIndex}
  #
  # Uses getIndexedTextContent to index the text, which accounts for line breaks
  # from DIVs and BRs. For ranges, the index takes into account the start and end
  # offsets of the range.
  getSelectionTextIndex: (refRangeOrNode) ->
    return null unless DOMUtils.selectionStartsOrEndsIn(refRangeOrNode)
    sel = @rawSelection
    return null unless sel
    startIndex = null
    endIndex = null
    range = null
    rangeOffset = 0
    if refRangeOrNode instanceof Range
      range = refRangeOrNode
      parentNode = range.commonAncestorContainer
    else
      parentNode = refRangeOrNode

    # If the selection is directly on the parent node, just return the
    # selection offsets
    if parentNode is sel.anchorNode
      if range then rangeOffset = range.startOffset
      startIndex = sel.anchorOffset-rangeOffset
    if parentNode is sel.focusNode
      if range then rangeOffset = range.startOffset
      endIndex = sel.focusOffset-rangeOffset

    if parentNode is sel.anchorNode and parentNode is sel.focusNode
      return {startIndex, endIndex}

    # Otherwise find the start and end index within a text representation of the
    # parent node
    for {node, start, end} in DOMUtils.getIndexedTextContent(parentNode)
      if range?.startContainer is node
        rangeOffset = start + range.startOffset
      if sel.anchorNode is node
        startIndex = start + sel.anchorOffset - rangeOffset
      if sel.focusNode is node
        endIndex = start + sel.focusOffset - rangeOffset
    return {startIndex, endIndex}

  # Sets the current selection to start and end at the specified indices, relative
  # to the given Range or Node. This is the inverse of getSelectionByTextIndex.
  #
  # Uses getIndexedTextContent to index the text, which accounts for line breaks
  # from DIVs and BRs. For ranges, the index takes into account the start and end
  # offsets of the range.
  restoreSelectionByTextIndex: (refRangeOrNode, startIndex, endIndex) ->
    startNode = null
    startOffset = null
    endNode = null
    endOffset = null
    range = null
    sel = @rawSelection
    if refRangeOrNode instanceof Range
      range = refRangeOrNode
      parentNode = range.commonAncestorContainer
    else
      parentNode = refRangeOrNode

    if parentNode.childNodes.length == 0 # text node
      sel.setBaseAndExtent(parentNode, startIndex, parentNode, endIndex)

    inRange = (range is null) # we're not in range yet, unless there is no range
    items = DOMUtils.getIndexedTextContent(parentNode)
    for {node, start, end},i in items
      inRange = inRange or (range.startContainer is node)
      atEnd = i==(items.length-1)
      if not inRange
        continue
      if range?.startContainer is node
        rangeOffset = start + range.startIndex
        if startIndex? then startIndex += rangeOffset
        if endIndex? then endIndex += rangeOffset
      if startIndex? and startIndex >= start and (startIndex < end or atEnd and startIndex==end)
        startNode = node
        startOffset = startIndex - start
      if endIndex? and endIndex >= start and (endIndex < end or atEnd and endIndex==end)
        endNode = node
        endOffset = endIndex - start
    sel.setBaseAndExtent(startNode ? sel.anchorNode, startOffset ? sel.anchorOffset, endNode ? sel.focusNode, endOffset ? sel.focusOffset)


  Object.defineProperty @prototype, "anchorNode",
    get: -> @rawSelection.anchorNode
    set: -> throw @_errNoSet("anchorNode")
  Object.defineProperty @prototype, "anchorOffset",
    get: -> @rawSelection.anchorOffset
    set: -> throw @_errNoSet("anchorOffset")
  Object.defineProperty @prototype, "focusNode",
    get: -> @rawSelection.focusNode
    set: -> throw @_errNoSet("focusNode")
  Object.defineProperty @prototype, "focusOffset",
    get: -> @rawSelection.focusOffset
    set: -> throw @_errNoSet("focusOffset")
  Object.defineProperty @prototype, "isCollapsed",
    get: -> @rawSelection.isCollapsed
    set: -> throw @_errNoSet("isCollapsed")
  Object.defineProperty @prototype, "rangeCount",
    get: -> @rawSelection.rangeCount
    set: -> throw @_errNoSet("rangeCount")

  setBaseAndExtent: (args...) -> @rawSelection.setBaseAndExtent(args...)
  getRangeAt: (args...) -> @rawSelection.getRangeAt(args...)
  collapse: (args...) -> @rawSelection.collapse(args...)
  extend: (args...) -> @rawSelection.extend(args...)
  modify: (args...) -> @rawSelection.modify(args...)
  collapseToStart: (args...) -> @rawSelection.collapseToStart(args...)
  collapseToEnd: (args...) -> @rawSelection.collapseToEnd(args...)
  selectAllChildren: (args...) -> @rawSelection.selectAllChildren(args...)
  addRange: (args...) -> @rawSelection.addRange(args...)
  removeRange: (args...) -> @rawSelection.removeRange(args...)
  removeAllRanges: (args...) -> @rawSelection.removeAllRanges(args...)
  deleteFromDocument: (args...) -> @rawSelection.deleteFromDocument(args...)
  toString: (args...) -> @rawSelection.toString(args...)
  containsNode: (args...) -> @rawSelection.containsNode(args...)

  _errBadUsage: -> new Error("Invalid arguments")
  _errNoSet: (property) -> new Error("Can't set #{property}")


module.exports = ExtendedSelection
