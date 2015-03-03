_ = require 'underscore-plus'
React = require 'react'
sanitizeHtml = require 'sanitize-html'
{Utils} = require 'inbox-exports'
FloatingToolbar = require './floating-toolbar.cjsx'

module.exports =
ContenteditableComponent = React.createClass
  getInitialState: ->
    toolbarTop: 0
    toolbarMode: "buttons"
    toolbarLeft: 0
    editAreaWidth: 9999 # This will get set on first selection
    toolbarVisible: false
    editQuotedText: false

  componentDidMount: ->
    @_setupSelectionListeners()
    @_setupLinkHoverListeners()

  componentWillUnmount: ->
    @_teardownSelectionListeners()
    @_teardownLinkHoverListeners()

  componentWillReceiveProps: (nextProps) ->
    if nextProps.initialSelectionSnapshot?
      @_setSelectionSnapshot(nextProps.initialSelectionSnapshot)

  componentWillUpdate: ->
    @_teardownLinkHoverListeners()

  componentDidUpdate: ->
    @_setupLinkHoverListeners()
    @_restoreSelection()

  render: ->
    <div className="contenteditable-container">
      <FloatingToolbar ref="floatingToolbar"
                       top={@state.toolbarTop}
                       left={@state.toolbarLeft}
                       visible={@state.toolbarVisible}
                       tabIndex={@props.tabIndex}
                       onSaveUrl={@_onSaveUrl}
                       initialMode={@state.toolbarMode}
                       onMouseEnter={@_onTooltipMouseEnter}
                       onMouseLeave={@_onTooltipMouseLeave}
                       linkToModify={@state.linkToModify}
                       contentPadding={@CONTENT_PADDING}
                       editAreaWidth={@state.editAreaWidth} />
      <div id="contenteditable"
           ref="contenteditable"
           contentEditable
           tabIndex={@props.tabIndex}
           onBlur={@_onBlur}
           onPaste={@_onPaste}
           onInput={@_onInput}
           onMouseUp={@_onMouseUp}
           onMouseDown={@_onMouseDown}
           dangerouslySetInnerHTML={@_dangerouslySetInnerHTML()}></div>
      <a className={@_quotedTextClasses()} onClick={@_onToggleQuotedText}></a>
    </div>

  focus: ->
    @_editableNode().focus() if @isMounted()

  _onInput: (event) ->
    @_editableNode().normalize()
    @_setNewSelectionState()
    html = @_unapplyHTMLDisplayFilters(@_editableNode().innerHTML)
    @props.onChange(target: value: html)

  _onBlur: (event) ->
    # The delay here is necessary to see if the blur was caused by us
    # navigating to the toolbar and focusing on the set-url input.
    _.delay =>
      return unless @isMounted() # Who knows what can happen in 50ms
      @_hideToolbar()
    , 50

  _editableNode: -> @refs.contenteditable.getDOMNode()

  _getAllLinks: ->
    Array.prototype.slice.call(@_editableNode().querySelectorAll("*[href]"))

  _dangerouslySetInnerHTML: ->
    __html: @_applyHTMLDisplayFilters(@props.html)

  _applyHTMLDisplayFilters: (html) ->
    html = @_ensureNotCompletelyBlank(html)
    html = @_removeQuotedTextFromHTML(html) unless @state.editQuotedText
    return html

  _unapplyHTMLDisplayFilters: (html) ->
    html = @_addQuotedTextToHTML(html) unless @state.editQuotedText
    return html




  ######### SELECTION MANAGEMENT ##########
  #
  # Saving and restoring a selection is difficult with React.
  #
  # React only handles Input and Textarea elements:
  # https://github.com/facebook/react/blob/master/src/browser/ui/ReactInputSelection.js
  # This is because they expose a very convenient `selectionStart` and
  # `selectionEnd` integer.
  #
  # Contenteditable regions are trickier. They require the more
  # sophisticated `Range` and `Selection` APIs.
  #
  # Range docs:
  # http://www.w3.org/TR/DOM-Level-2-Traversal-Range/ranges.html
  #
  # Selection API docs:
  # http://www.w3.org/TR/selection-api/#dfn-range
  #
  # A Contenteditable region can have arbitrary html inside of it. This
  # means that a selection start point can be some node (the `anchorNode`)
  # and its end point can be a completely different node (the `focusNode`)
  #
  # When React re-renders, all of the DOM nodes may change. They may
  # look exactly the same, but have different object references.
  #
  # This means that your old references to `anchorNode` and `focusNode`
  # may be bad and no longer in scope or painted.
  #
  # In order to restore the selection properly we need to re-find the
  # equivalent `anchorNode` and `focusNode`. Luckily we can use the
  # `isEqualNode` method to get a shallow comparison of the nodes.
  #
  # Unfortunately it's possible for `isEqualNode` to match more than one
  # node since two nodes may look very similar.
  #
  # To fix this we need to keep track of the original indices to determine
  # which node is most likely the matching one.

  # http://www.w3.org/TR/selection-api/#selectstart-event
  _setupSelectionListeners: ->
    @_onSelectionChange = => @_setNewSelectionState()
    document.addEventListener "selectionchange", @_onSelectionChange

  _teardownSelectionListeners: ->
    document.removeEventListener("selectionchange", @_onSelectionChange)

  getCurrentSelection: -> _.clone(@_selection ? {})
  getPreviousSelection: -> _.clone(@_previousSelection ? {})

  # Every time the cursor changes we need to preserve its location and
  # state.
  #
  # We can't use React's `state` variable because cursor position is not
  # natrually supported in the virtual DOM.
  #
  # We also need to make sure that node references are cloned so they
  # don't change out from underneath us.
  #
  # We also need to keep references to the previous selection state in
  # order for undo/redo to work properly.
  #
  # We need to be sure to deeply `cloneNode`. This is because sometimes
  # our anchorNodes are divs with nested <br> tags. If we don't do a deep
  # clone then when `isEqualNode` is run it will erroneously return false
  # and our selection restoration will fail
  _setNewSelectionState: ->
    selection = document.getSelection()
    return if not @_selectionInScope(selection)
    # @_setSelectionMarkers()

    return if @_checkSameSelection(selection)
    try
      range = selection.getRangeAt(0)
    catch
      return
    return if not range?

    @_previousSelection = @_selection
    @_selection =
      startNode: range.startContainer?.cloneNode(true)
      startOffset: range.startOffset
      startNodeIndex: @_getNodeIndex(range.startContainer)
      endNode: range.endContainer?.cloneNode(true)
      endOffset: range.endOffset
      endNodeIndex: @_getNodeIndex(range.endContainer)

    @_refreshToolbarState()
    return @_selection

  # _setSelectionMarkers: (selection) ->
  #   startMarker = document.createElement("SPAN")
  #   startMarker.setAttribute "id", "nilas-start-marker"
  #   endMarker = document.createElement("SPAN")
  #   endMarker.setAttribute "id", "nilas-end-marker"
  #   selection.anchorNode.parentNode.insertBefore(startMarker, selection.anchorNode)
  #   selection.focusNode.parentNode.insertBefore(endMarker, selection.focusNode)

  _setSelectionSnapshot: (selection) -> @_selection = selection

  # When we're dragging we don't want to the restoring the cursor as we're
  # dragging. Doing so caused selecting backwards to break because the
  # Selection API does not yet expose the selection "direction". When we
  # would go to reset the cursor selection, it would reset to the wrong
  # state.
  _onMouseDown: (event) ->
    @_ignoreSelectionRestoration = true
    return true
  _onMouseUp: ->
    @_ignoreSelectionRestoration = false
    return true

  # We manually restore the selection on every render and when we need to
  # move the selection around manually.
  #
  # force - when set to true it will not care whether or not the selection
  #         is already in the box. Normally we only restore when the
  #         contenteditable is in focus
  # collapse - Can either be "end" or "start". When we reset the
  #            selection, we'll collapse the range into a single caret
  #            position
  _restoreSelection: ({force, collapse}={}) ->
    return if @_ignoreSelectionRestoration
    return if not @_selection?
    return if document.activeElement isnt @_editableNode() and not force
    return if not @_selection.startNode? or not @_selection.endNode?
    range = document.createRange()

    startNode = @_findSimilarNodes(@_selection.startNode)[@_selection.startNodeIndex]
    endNode = @_findSimilarNodes(@_selection.endNode)[@_selection.endNodeIndex]
    return if not startNode? or not endNode?


    startIndex = Math.min(@_selection.startOffset ? 0, @_selection.endOffset ? 0)
    startIndex = Math.min(startIndex, startNode.length)

    endIndex = Math.max(@_selection.startOffset ? 0, @_selection.endOffset ? 0)
    endIndex = Math.min(endIndex, endNode.length)

    if collapse is "end"
      startNode = endNode
      startIndex = endIndex
    else if collapse is "start"
      endNode = startNode
      endIndex = endIndex


    try
      range.setStart(startNode, startIndex)
      range.setEnd(endNode, endIndex)
    catch
      return

    selection = document.getSelection()
    @_teardownSelectionListeners()
    selection.removeAllRanges()
    selection.addRange(range)
    @_setupSelectionListeners()

  # We need to break each node apart and cache since the `selection`
  # object will mutate underneath us.
  _checkSameSelection: (selection) ->
    return true if not selection?
    return false if not @_previousSelection
    return false if not selection.anchorNode? or not selection.focusNode?

    anchorIndex = @_getNodeIndex(selection.anchorNode)
    focusIndex = @_getNodeIndex(selection.focusNode)

    anchorEqual = selection.anchorNode.isEqualNode @_previousSelection.startNode
    anchorIndexEqual = anchorIndex is @_previousSelection.startNodeIndex
    focusEqual = selection.focusNode.isEqualNode @_previousSelection.endNode
    focusIndexEqual = focusIndex is @_previousSelection.endNodeIndex
    if not anchorEqual and not focusEqual
      # This means the selection is the same, but just from the opposite
      # direction. We don't care in this case, so check the reciprocal as
      # well.
      anchorEqual = selection.anchorNode.isEqualNode @_previousSelection.endNode
      anchorIndexEqual = anchorIndex is @_previousSelection.endNodeIndex
      focusEqual = selection.focusNode.isEqualNode @_previousSelection.startNode
      focusIndexEqual = focusIndex is @_previousSelection.startndNodeIndex

    anchorOffsetEqual = selection.anchorOffset == @_previousSelection.startOffset
    focusOffsetEqual = selection.focusOffset == @_previousSelection.endOffset
    if not anchorOffsetEqual and not focusOffsetEqual
      # This means the selection is the same, but just from the opposite
      # direction. We don't care in this case, so check the reciprocal as
      # well.
      anchorOffsetEqual = selection.anchorOffset == @_previousSelection.focusOffset
      focusOffsetEqual = selection.focusOffset == @_previousSelection.anchorOffset

    if (anchorEqual and
        anchorIndexEqual and
        anchorOffsetEqual and
        focusEqual and
        focusIndexEqual and
        focusOffsetEqual)
      return true
    else
      return false

  _getNodeIndex: (nodeToFind) ->
    @_findSimilarNodes(nodeToFind).indexOf nodeToFind

  _findSimilarNodes: (nodeToFind) ->
    nodeList = []
    treeWalker = document.createTreeWalker @_editableNode()
    while treeWalker.nextNode()
      if treeWalker.currentNode.isEqualNode nodeToFind
        nodeList.push(treeWalker.currentNode)

    return nodeList

  _isEqualNode: ->

  # This is so the contenteditable can have a non-blank TextNode for the
  # selection to lock onto.
  _ensureNotCompletelyBlank: (html) ->
    if html.length is 0
      return "&nbsp;"
    else return html

  _linksInside: (selection) ->
    return _.filter @_getAllLinks(), (link) ->
      selection.containsNode(link, true)




  ####### TOOLBAR ON SELECTION #########

  # We want the toolbar's state to be declaratively defined from other
  # states.
  #
  # There are a variety of conditions that the toolbar should display:
  # 1. When you're hovering over a link
  # 2. When you've arrow-keyed the cursor into a link
  # 3. When you have selected a range of text.
  _refreshToolbarState: ->
    if @_linkHoveringOver
      url = @_linkHoveringOver.getAttribute('href')
      rect = @_linkHoveringOver.getBoundingClientRect()
      [left, top, editAreaWidth] = @_getToolbarPos(rect)
      @setState
        toolbarVisible: true
        toolbarMode: "edit-link"
        toolbarTop: top
        toolbarLeft: left
        linkToModify: @_linkHoveringOver
        editAreaWidth: editAreaWidth
    else
      selection = document.getSelection()

      # TODO do something smarter then this in the future
      linksInside = [] # @_linksInside(selection)

      if selection.isCollapsed and linksInside.length is 0
        @_hideToolbar()
      else
        if selection.isCollapsed and linksInside.length > 0
          linkRect = linksInside[0].getBoundingClientRect()
          [left, top, editAreaWidth] = @_getToolbarPos(linkRect)
        else
          selectionRect = selection.getRangeAt(0).getBoundingClientRect()
          [left, top, editAreaWidth] = @_getToolbarPos(selectionRect)

        @setState
          toolbarVisible: true
          toolbarMode: "buttons"
          toolbarTop: top
          toolbarLeft: left
          linkToModify: null
          editAreaWidth: editAreaWidth

  # See selection API: http://www.w3.org/TR/selection-api/
  _selectionInScope: (selection) ->
    return false if not selection?
    return false if not @isMounted()
    editNode = @refs.contenteditable.getDOMNode()
    return (editNode.contains(selection.anchorNode) and
            editNode.contains(selection.focusNode))

  CONTENT_PADDING: 15

  _getToolbarPos: (referenceRect) ->

    TOP_PADDING = 10

    editArea = @refs.contenteditable.getDOMNode().getBoundingClientRect()

    calcLeft = (referenceRect.left - editArea.left) + referenceRect.width/2
    calcLeft = Math.min(Math.max(calcLeft, @CONTENT_PADDING), editArea.width)

    calcTop = referenceRect.top - editArea.top + referenceRect.height + TOP_PADDING

    return [calcLeft, calcTop, editArea.width]

  _hideToolbar: ->
    if not @_focusedOnToolbar() and @state.toolbarVisible
      @setState toolbarVisible: false

  _focusedOnToolbar: ->
    @refs.floatingToolbar.getDOMNode().contains(document.activeElement)

  # This needs to be in the contenteditable area because we need to first
  # restore the selection before calling the `execCommand`
  #
  # If the url is empty, that means we want to remove the url.
  _onSaveUrl: (url, linkToModify) ->
    if linkToModify?
      linkToModify = @_findSimilarNodes(linkToModify)?[0]?.childNodes[0]
      return if not linkToModify?
      range = document.createRange()
      try
        range.setStart(linkToModify, 0)
        range.setEnd(linkToModify, linkToModify.length)
      catch
        return
      selection = document.getSelection()
      @_teardownSelectionListeners()
      selection.removeAllRanges()
      selection.addRange(range)
      if url.trim().length is 0
        document.execCommand("unlink", false)
      else
        document.execCommand("createLink", false, url)
      @_setupSelectionListeners()
    else
      @_restoreSelection(force: true)
      if document.getSelection().isCollapsed
        # TODO
      else
        if url.trim().length is 0
          document.execCommand("unlink", false)
        else
          document.execCommand("createLink", false, url)
        @_restoreSelection(force: true, collapse: "end")

  _setupLinkHoverListeners: ->
    HOVER_IN_DELAY = 250
    HOVER_OUT_DELAY = 1000
    @_links = []
    links =  @_getAllLinks()
    return if links.length is 0
    links.forEach (link) =>
      enterTimeout = null
      leaveTimeout = null

      enterListener = (event) =>
        enterTimeout = setTimeout =>
          return unless @isMounted()
          @_linkHoveringOver = link
          @_refreshToolbarState()
        , HOVER_IN_DELAY
      leaveListener = (event) =>
        leaveTimeout = setTimeout =>
          @_linkHoveringOver = null
          return unless @isMounted()
          return if @refs.floatingToolbar.isHovering
          @_refreshToolbarState()
        , HOVER_OUT_DELAY
        clearTimeout(enterTimeout)

      link.addEventListener "mouseenter", enterListener
      link.addEventListener "mouseleave", leaveListener
      @_links.push
        link: link
        enterTimeout: enterTimeout
        leaveTimeout: leaveTimeout
        enterListener: enterListener
        leaveListener: leaveListener

  _onTooltipMouseEnter: ->
    clearTimeout(@_clearTooltipTimeout) if @_clearTooltipTimeout?

  _onTooltipMouseLeave: ->
    @_clearTooltipTimeout = setTimeout =>
      @_refreshToolbarState()
    , 500

  _teardownLinkHoverListeners: ->
    while @_links.length > 0
      linkData = @_links.pop()
      clearTimeout linkData.enterTimeout
      clearTimeout linkData.leaveTimeout
      linkData.link.removeEventListener "mouseenter", linkData.enterListener
      linkData.link.removeEventListener "mouseleave", linkData.leaveListener




  ####### CLEAN PASTE #########

  _onPaste: (evt) ->
    html = evt.clipboardData.getData("text/html") ? ""
    if html.length is 0
      text = evt.clipboardData.getData("text/plain") ? ""
      if text.length > 0
        evt.preventDefault()
        cleanHtml = text
      else
    else
      evt.preventDefault()
      cleanHtml = @_sanitizeHtml(html)

    document.execCommand("insertHTML", false, cleanHtml)
    return false

  # This is used primarily when pasting text in
  _sanitizeHtml: (html) ->
    cleanHtml = sanitizeHtml html.replace(/\n/g, "<br/>"),
      allowedTags: ['p', 'b', 'i', 'em', 'strong', 'a', 'br', 'img', 'ul', 'ol', 'li', 'strike']
      allowedAttributes:
        a: ['href', 'name']
        img: ['src', 'alt']
      transformTags:
        h1: "p"
        h2: "p"
        h3: "p"
        h4: "p"
        h5: "p"
        h6: "p"
        div: "p"
        pre: "p"
        blockquote: "p"
        table: "p"

    cleanHtml.replace(/<p>/gi, "").replace(/<\/p>/gi, "<br/><br/>")




  ####### QUOTED TEXT #########

  _onToggleQuotedText: ->
    @setState
      editQuotedText: !@state.editQuotedText

  _quotedTextClasses: -> React.addons.classSet
    "quoted-text-control": true
    "no-quoted-text": @_htmlQuotedTextStart() is -1
    "show-quoted-text": @state.editQuotedText

  _htmlQuotedTextStart: ->
    @props.html.search(/<[^>]*gmail_quote/)

  _removeQuotedTextFromHTML: (html) ->
    quoteStart = @_htmlQuotedTextStart()
    if quoteStart is -1 then return html
    else return html.substr(0, quoteStart)

  _addQuotedTextToHTML: (innerHTML) ->
    quoteStart = @_htmlQuotedTextStart()
    if quoteStart is -1 then return innerHTML
    else return (innerHTML + @props.html.substr(quoteStart))
