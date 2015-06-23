_ = require 'underscore'
React = require 'react'
classNames = require 'classnames'
sanitizeHtml = require 'sanitize-html'
{Utils, DraftStore} = require 'nylas-exports'
FloatingToolbar = require './floating-toolbar'

linkUUID = 0
genLinkId = -> linkUUID += 1; return linkUUID

class ContenteditableComponent extends React.Component
  @displayName = "Contenteditable"
  @propTypes =
    html: React.PropTypes.string
    style: React.PropTypes.object
    tabIndex: React.PropTypes.string
    onChange: React.PropTypes.func.isRequired
    mode: React.PropTypes.object
    onFilePaste: React.PropTypes.func
    onChangeMode: React.PropTypes.func
    initialSelectionSnapshot: React.PropTypes.object

    # Passes an absolute top coordinate to scroll to.
    onRequestScrollTo: React.PropTypes.func

  constructor: (@props) ->
    @state =
      toolbarTop: 0
      toolbarMode: "buttons"
      toolbarLeft: 0
      toolbarPos: "above"
      editAreaWidth: 9999 # This will get set on first selection
      toolbarVisible: false

  componentDidMount: =>
    @_editableNode().addEventListener('contextmenu', @_onShowContextualMenu)
    @_setupSelectionListeners()
    @_setupLinkHoverListeners()
    @_setupGlobalMouseListener()

    @_disposable = atom.commands.add '.contenteditable-container *', {
      'core:focus-next': (event) =>
        editableNode = @_editableNode()
        range = @_getRangeInScope()
        for extension in DraftStore.extensions()
          extension.onFocusNext(editableNode, range, event) if extension.onFocusNext

      'core:focus-previous': (event) =>
        editableNode = @_editableNode()
        range = @_getRangeInScope()
        for extension in DraftStore.extensions()
          extension.onFocusPrevious(editableNode, range, event) if extension.onFocusPrevious
      }

    @_cleanHTML()

  shouldComponentUpdate: (nextProps, nextState) ->
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  componentWillUnmount: =>
    @_editableNode().removeEventListener('contextmenu', @_onShowContextualMenu)
    @_teardownSelectionListeners()
    @_teardownLinkHoverListeners()
    @_teardownGlobalMouseListener()
    @_disposable.dispose()

  componentWillReceiveProps: (nextProps) =>
    if nextProps.initialSelectionSnapshot?
      @_setSelectionSnapshot(nextProps.initialSelectionSnapshot)
      @_refreshToolbarState()

  componentWillUpdate: (nextProps, nextState) =>
    @_teardownLinkHoverListeners()

  componentDidUpdate: =>
    @_cleanHTML()
    @_setupLinkHoverListeners()
    @_restoreSelection()

  render: =>
    <div className="contenteditable-container">
      <FloatingToolbar ref="floatingToolbar"
                       top={@state.toolbarTop}
                       left={@state.toolbarLeft}
                       pos={@state.toolbarPos}
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
           style={@props.style ? {}}
           onBlur={@_onBlur}
           onClick={@_onClick}
           onPaste={@_onPaste}
           onInput={@_onInput}
           dangerouslySetInnerHTML={@_dangerouslySetInnerHTML()}></div>
      <a className={@_quotedTextClasses()} onClick={@_onToggleQuotedText}></a>
    </div>

  focus: =>
    @_editableNode().focus()

  selectEnd: =>
    range = document.createRange()
    range.selectNodeContents(@_editableNode())
    range.collapse(false)
    @_editableNode().focus()
    selection = window.getSelection()
    selection.removeAllRanges()
    selection.addRange(range)

  _onClick: (event) ->
    # We handle mouseDown, mouseMove, mouseUp, but we want to stop propagation
    # of `click` to make it clear that we've handled the event.
    # Note: Related to composer-view#_onClickComposeBody
    event.stopPropagation()

  _onInput: (event) =>
    @_dragging = false

    @_runExtensionFilters()

    @_prepareForReactContenteditable()

    @_saveSelectionState()

    html = @_unapplyHTMLDisplayFilters(@_editableNode().innerHTML)
    @props.onChange(target: {value: html})

  _runExtensionFilters: ->
    for extension in DraftStore.extensions()
      extension.onInput(@_editableNode(), event) if extension.onInput

  # This component works by re-rendering on every change and restoring the
  # selection. This is also how standard React controlled inputs work too.
  #
  # Since the contets of the contenteditable are complex, nested DOM
  # structures, a simple replacement of the DOM is not easy. There are a
  # variety of edge cases that we need to correct for and prepare both the
  # HTML and the selection to be serialized without error.
  _prepareForReactContenteditable: ->
    @_cleanHTML()
    @_cleanSelection()

  # We need to clean the HTML on input to fix several edge cases that
  # arise when we go to save the selection state and restore it on the
  # next render.
  _cleanHTML: ->
    return unless @_editableNode()

    # One issue is that we need to pre-normalize the HTML so it looks the
    # same after it gets re-inserted. If we key selection markers off of an
    # non normalized DOM, then they won't match up when the HTML gets reset.
    #
    # The Node.normalize() method puts the specified node and all of its
    # sub-tree into a "normalized" form. In a normalized sub-tree, no text
    # nodes in the sub-tree are empty and there are no adjacent text
    # nodes.
    @_editableNode().normalize()

    @_fixLeadingBRCondition()

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
  _fixLeadingBRCondition: ->
    treeWalker = document.createTreeWalker @_editableNode()
    while treeWalker.nextNode()
      currentNode = treeWalker.currentNode
      if @_hasLeadingBRCondition(currentNode)
        newNode = document.createElement("div")
        newNode.appendChild(document.createElement("br"))
        currentNode.replaceChild(newNode, currentNode.childNodes[0])
    return

  _hasLeadingBRCondition: (node) ->
    childNodes = node.childNodes
    return childNodes.length >= 2 and childNodes[0].nodeName is "BR"

  # After an input, the selection can sometimes get itself into a state
  # that either can't be restored properly, or will cause undersirable
  # native behavior. This method, in combination with `_cleanHTML`, fixes
  # each of those scenarios before we save and later restore the
  # selection.
  _cleanSelection: ->
    selection = document.getSelection()
    return unless selection.anchorNode? and selection.focusNode?

    # The _unselectableNode case only is valid when it's at the very top
    # (offset 0) of the node. If the offsets are > 0 that means we're
    # trying to select somewhere within some sort of containing element.
    # This is okay to do. The odd case only arises at the top of
    # unselectable elements.
    return if selection.anchorOffset > 0 or selection.focusOffset > 0

    if selection.isCollapsed and @_unselectableNode(selection.focusNode)
      @_teardownSelectionListeners()
      treeWalker = document.createTreeWalker(selection.focusNode)
      while treeWalker.nextNode()
        currentNode = treeWalker.currentNode
        if @_unselectableNode(currentNode)
          selection.setBaseAndExtent(currentNode, 0, currentNode, 0)
          break
      @_setupSelectionListeners()
    return

  _unselectableNode: (node) ->
    return true if not node
    if node.nodeType is Node.TEXT_NODE and @_isBlankTextNode(node)
      return true
    else if node.nodeType is Node.ELEMENT_NODE
      child = node.firstChild
      return true if not child
      hasText = (child.nodeType is Node.TEXT_NODE and not @_isBlankTextNode(node))
      hasBr = (child.nodeType is Node.ELEMENT_NODE and node.nodeName is "BR")
      return not hasText and not hasBr

    else return false

  _onBlur: (event) =>
    @_dragging = false
    # The delay here is necessary to see if the blur was caused by us
    # navigating to the toolbar and focusing on the set-url input.
    _.delay =>
      @_hideToolbar()
    , 50

  _editableNode: =>
    React.findDOMNode(@refs.contenteditable)

  _getAllLinks: =>
    Array.prototype.slice.call(@_editableNode().querySelectorAll("*[href]"))

  _dangerouslySetInnerHTML: =>
    __html: @_applyHTMLDisplayFilters(@props.html)

  _applyHTMLDisplayFilters: (html) =>
    html = @_removeQuotedTextFromHTML(html) unless @props.mode?.showQuotedText
    return html

  _unapplyHTMLDisplayFilters: (html) =>
    html = @_addQuotedTextToHTML(html) unless @props.mode?.showQuotedText
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
  _setupSelectionListeners: =>
    @_onSelectionChange = => @_saveSelectionState()
    document.addEventListener "selectionchange", @_onSelectionChange

  _teardownSelectionListeners: =>
    document.removeEventListener("selectionchange", @_onSelectionChange)

  getCurrentSelection: => _.clone(@_selection ? {})
  getPreviousSelection: => _.clone(@_previousSelection ? {})

  _getRangeInScope: =>
    selection = document.getSelection()
    return null if not @_selectionInScope(selection)
    try
      range = selection.getRangeAt(0)
    catch
      console.warn "Selection is not returning a range"
      return document.createRange()
    range

  # Every time the cursor changes we need to preserve its location and
  # state.
  #
  # We can't use React's `state` variable because cursor position is not
  # naturally supported in the virtual DOM.
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
  # and our selection restoration will fail.
  #
  # The Selection API has the concept of an `anchorNode` and a
  # `focusNode`. The `anchorNode` is where the selection started from and
  # does not move. The `focusNode` is where the end of the selection
  # currently is and may move. A "caret" is simply a selection whose
  # anchorNode == focusNode and anchorOffset == focusOffset.
  #
  # An `anchorNode` is also known as a `startNode`, or `baseNode`. We use
  # the alias `startNode` since I think it makes more intuitive sense.
  #
  # A `focusNode` is also known as an `endNode` or `focusNode`. I use the
  # `endNode` alias since it makes more inuitive sense.
  #
  # When we restore the selection later, we need to find a node that looks
  # the same as the one we saved (since they're different object
  # references). Unfortunately there many be many nodes that "look" the
  # same (match the `isEqualNode`) test. For example, say I have a bunch
  # of lines with the TEXT_NODE "Foo". All of those will match
  # `isEqualNode`. To fix this we assume there will be multiple matches
  # and keep track of the index of the match. e.g. all "Foo" TEXT_NODEs
  # may look alike, but I know I want the Nth "Foo" TEXT_NODE. We store
  # this information in the `startNodeIndex` and `endNodeIndex` fields via
  # the `getNodeIndex` method.
  _saveSelectionState: =>
    selection = document.getSelection()
    return if @_checkSameSelection(selection)
    return unless selection.anchorNode? and selection.focusNode?
    return unless @_selectionInScope(selection)

    @_previousSelection = @_selection

    @_selection =
      startNode: selection.anchorNode.cloneNode(true)
      startOffset: selection.anchorOffset
      startNodeIndex: @_getNodeIndex(selection.anchorNode)
      endNode: selection.focusNode.cloneNode(true)
      endOffset: selection.focusOffset
      endNodeIndex: @_getNodeIndex(selection.focusNode)
      isCollapsed: selection.isCollapsed
      atEndOfContent: @_atEndOfContent(selection)

    @_refreshToolbarState()
    return @_selection

  # Determines whether the current (cursor) selection is at the end of the
  # content.
  #
  # This must be run before a re-render since we use a strict object
  # identity comparison instead of an equivalent `isEqualNode` comparison.
  _atEndOfContent: (selection, containerScope=@_editableNode()) =>
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
      lastChild = @_lastNonBlankChildNode(containerScope)

      # Special case for a completely empty contenteditable.
      # In this case `lastChild` will be null, but we are definitely at
      # the end of the content.
      if containerScope is @_editableNode()
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
        @_atEndOfContent(selection, lastChild)
      else return false

    else return false

  _lastNonBlankChildNode: (node) ->
    lastNode = null
    for childNode in node.childNodes by -1
      if childNode.nodeType is Node.TEXT_NODE
        if @_isBlankTextNode(childNode)
          continue
        else
          return childNode
      else if childNode.nodeType is Node.ELEMENT_NODE
        return childNode
      else continue
    return lastNode

  _isBlankTextNode: (node) ->
    return if not node?.data
    # \u00a0 is &nbsp;
    node.data.replace(/\u00a0/g, "x").trim().length is 0

  _setSelectionSnapshot: (selection) =>
    @_previousSelection = @_selection
    @_selection = selection

    # We need to use a boolean flag here because this runs before anything
    # might be rendered yet.
    @_selectionManuallyChanged = true

  # When the selectionState gets set by a parent (e.g. undo-ing and
  # redo-ing) we need to make sure it's visible to the user.
  #
  # Unfortunately, we can't use the native `scrollIntoView` because it
  # naively scrolls the whole window and doesn't know not to scroll if
  # it's already in view. There's a new native method called
  # `scrollIntoViewIfNeeded`, but this only works when the scroll
  # container is a direct parent of the requested element. In this case
  # the scroll container may be many levels up.
  _ensureSelectionVisible: (selection) ->
    rect = @_getRangeInScope().getBoundingClientRect()
    return if @_isEmptyBoudingRect(rect)
    top = @_getSelectionTop(selection, rect)
    @props.onRequestScrollTo?(selectionTop: top)
    @_refreshToolbarState()

  _isEmptyBoudingRect: (rect) ->
    rect.top is 0 and rect.bottom is 0 and rect.left is 0 and rect.right is 0

  _getSelectionTop: (selection, rect) ->
    if rect then return rect.top + (Math.abs(rect.top - rect.bottom) / 2)
    node = selection.anchorNode
    if node.nodeType is Node.TEXT_NODE
      r = document.createRange()
      r.selectNodeContents(node)
      rect = r.getBoundingClientRect()
    else if node.nodeType is Node.ELEMENT_NODE
      rect = node.getBoundingClientRect()
    else
      rect = {top: 0, bottom: 0}

    return rect.top + Math.abs(rect.top - rect.bottom) / 2

  # We use global listeners to determine whether or not dragging is
  # happening. This is because dragging may stop outside the scope of
  # this element. Note that the `dragstart` and `dragend` events don't
  # detect text selection. They are for drag & drop.
  _setupGlobalMouseListener: =>
    @__onMouseDown = _.bind(@_onMouseDown, @)
    @__onMouseMove = _.bind(@_onMouseMove, @)
    @__onMouseUp = _.bind(@_onMouseUp, @)
    window.addEventListener("mousedown", @__onMouseDown)
    window.addEventListener("mouseup", @__onMouseUp)

  _teardownGlobalMouseListener: =>
    window.removeEventListener("mousedown", @__onMouseDown)
    window.removeEventListener("mouseup", @__onMouseUp)

  _onShowContextualMenu: (event) =>
    @_hideToolbar()
    event.preventDefault()

    selection = document.getSelection()
    range = selection.getRangeAt(0)
    text = range.toString()

    remote = require('remote')
    clipboard = require('clipboard')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')
    spellchecker = require('spellchecker')

    apply = (newtext) =>
      range.deleteContents()
      node = document.createTextNode(newtext)
      range.insertNode(node)
      range.selectNode(node)
      selection.removeAllRanges()
      selection.addRange(range)

    cut = =>
      clipboard.writeText(text)
      apply('')

    copy = =>
      clipboard.writeText(text)

    paste = =>
      apply(clipboard.readText())

    menu = new Menu()

    if spellchecker.isMisspelled(text)
      corrections = spellchecker.getCorrectionsForMisspelling(text)
      if corrections.length > 0
        corrections.forEach (correction) ->
          menu.append(new MenuItem({ label: correction, click:( -> apply(correction))}))
        menu.append(new MenuItem({ type: 'separator' }))
        menu.append(new MenuItem({ label: 'Learn Spelling', click:( -> spellchecker.add(text))}))
        menu.append(new MenuItem({ type: 'separator' }))

    menu.append(new MenuItem({ label: 'Cut', click:cut}))
    menu.append(new MenuItem({ label: 'Copy', click:copy}))
    menu.append(new MenuItem({ label: 'Paste', click:paste}))
    menu.popup(remote.getCurrentWindow())

  _onMouseDown: (event) =>
    @_mouseDownEvent = event
    @_mouseHasMoved = false
    window.addEventListener("mousemove", @__onMouseMove)

    # We can't use the native double click event because that only fires
    # on the second up-stroke
    if Date.now() - (@_lastMouseDown ? 0) < 250
      @_onDoubleDown(event)
      @_lastMouseDown = 0 # to prevent triple down
    else
      @_lastMouseDown = Date.now()

  _onDoubleDown: (event) =>
    editable = @_editableNode()
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @_doubleDown = true

  _onMouseMove: (event) =>
    if not @_mouseHasMoved
      @_onDragStart(@_mouseDownEvent)
      @_mouseHasMoved = true

  _onMouseUp: (event) =>
    window.removeEventListener("mousemove", @__onMouseMove)

    if @_doubleDown
      @_doubleDown = false
      @_refreshToolbarState()

    if @_mouseHasMoved
      @_mouseHasMoved = false
      @_onDragEnd(event)

    editableNode = @_editableNode()
    selection = document.getSelection()
    return event unless @_selectionInScope(selection)

    range = @_getRangeInScope()
    if range
      try
        for extension in DraftStore.extensions()
          extension.onMouseUp(editableNode, range, event) if extension.onMouseUp
      catch e
        console.log('DraftStore extension raised an error: '+e.toString())

    event

  _onDragStart: (event) =>
    editable = @_editableNode()
    return unless editable?
    if editable is event.target or editable.contains(event.target)
      @_dragging = true

  _onDragEnd: (event) =>
    if @_dragging
      @_dragging = false
      @_refreshToolbarState()
    return event

  # We restore the Selection via the `setBaseAndExtent` property of the
  # `Selection` API
  #
  # See http://w3c.github.io/selection-api/#widl-Selection-setBaseAndExtent-void-Node-anchorNode-unsigned-long-anchorOffset-Node-focusNode-unsigned-long-focusOffset
  #
  # Since the last time we saved the `@_selection`, the DOM may have
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
  #
  # force - when set to true it will not care whether or not the selection
  #         is already in the box. Normally we only restore when the
  #         contenteditable is in focus
  # collapse - Can either be "end" or "start". When we reset the
  #            selection, we'll collapse the range into a single caret
  #            position
  _restoreSelection: ({force, collapse}={}) =>
    return if @_dragging
    return if not @_selection?
    return if document.activeElement isnt @_editableNode() and not force
    return if not @_selection.startNode? or not @_selection.endNode?

    newStartNode = @_findSimilarNodes(@_selection.startNode)[@_selection.startNodeIndex]
    newEndNode = @_findSimilarNodes(@_selection.endNode)[@_selection.endNodeIndex]
    return if not newStartNode? or not newEndNode?

    @_teardownSelectionListeners()
    selection = document.getSelection()
    selection.setBaseAndExtent(newStartNode,
                               @_selection.startOffset,
                               newEndNode,
                               @_selection.endOffset)
    if @_selectionManuallyChanged
      @_ensureSelectionVisible(selection)
      @_selectionManuallyChanged = false
    @_setupSelectionListeners()

  # We need to break each node apart and cache since the `selection`
  # object will mutate underneath us.
  _checkSameSelection: (newSelection) =>
    return true if not newSelection?
    return false if not @_selection
    return false if not newSelection.anchorNode? or not newSelection.focusNode?

    anchorIndex = @_getNodeIndex(newSelection.anchorNode)
    focusIndex = @_getNodeIndex(newSelection.focusNode)

    anchorEqual = newSelection.anchorNode.isEqualNode @_selection.startNode
    anchorIndexEqual = anchorIndex is @_selection.startNodeIndex
    focusEqual = newSelection.focusNode.isEqualNode @_selection.endNode
    focusIndexEqual = focusIndex is @_selection.endNodeIndex
    if not anchorEqual and not focusEqual
      # This means the newSelection is the same, but just from the opposite
      # direction. We don't care in this case, so check the reciprocal as
      # well.
      anchorEqual = newSelection.anchorNode.isEqualNode @_selection.endNode
      anchorIndexEqual = anchorIndex is @_selection.endNodeIndex
      focusEqual = newSelection.focusNode.isEqualNode @_selection.startNode
      focusIndexEqual = focusIndex is @_selection.startndNodeIndex

    anchorOffsetEqual = newSelection.anchorOffset == @_selection.startOffset
    focusOffsetEqual = newSelection.focusOffset == @_selection.endOffset
    if not anchorOffsetEqual and not focusOffsetEqual
      # This means the newSelection is the same, but just from the opposite
      # direction. We don't care in this case, so check the reciprocal as
      # well.
      anchorOffsetEqual = newSelection.anchorOffset == @_selection.focusOffset
      focusOffsetEqual = newSelection.focusOffset == @_selection.anchorOffset

    if (anchorEqual and
        anchorIndexEqual and
        anchorOffsetEqual and
        focusEqual and
        focusIndexEqual and
        focusOffsetEqual)
      return true
    else
      return false

  _getNodeIndex: (nodeToFind) =>
    @_findSimilarNodes(nodeToFind).indexOf nodeToFind

  _findSimilarNodes: (nodeToFind) =>
    nodeList = []
    editableNode = @_editableNode()
    if nodeToFind.isEqualNode(editableNode)
      nodeList.push(editableNode)
      return nodeList
    treeWalker = document.createTreeWalker editableNode
    while treeWalker.nextNode()
      if treeWalker.currentNode.isEqualNode nodeToFind
        nodeList.push(treeWalker.currentNode)

    return nodeList

  _isEqualNode: =>

  _linksInside: (selection) =>
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
  _refreshToolbarState: =>
    return if @_dragging or (@_doubleDown and not @state.toolbarVisible)
    if @_linkHoveringOver
      url = @_linkHoveringOver.getAttribute('href')
      rect = @_linkHoveringOver.getBoundingClientRect()
      [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(rect)
      @setState
        toolbarVisible: true
        toolbarMode: "edit-link"
        toolbarTop: top
        toolbarLeft: left
        toolbarPos: toolbarPos
        linkToModify: @_linkHoveringOver
        editAreaWidth: editAreaWidth
    else
      if not @_selection? or @_selection.isCollapsed
        @_hideToolbar()
      else
        if @_selection.isCollapsed
          linkRect = linksInside[0].getBoundingClientRect()
          isEmptyRect = @_isEmptyBoudingRect(linkRect)
          [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(linkRect)
        else
          selectionRect = @_getRangeInScope().getBoundingClientRect()
          isEmptyRect = @_isEmptyBoudingRect(selectionRect)
          [left, top, editAreaWidth, toolbarPos] = @_getToolbarPos(selectionRect)

        if isEmptyRect
          @setState
            toolbarVisible: false
        else
          @setState
            toolbarVisible: true
            toolbarMode: "buttons"
            toolbarTop: top
            toolbarLeft: left
            toolbarPos: toolbarPos
            linkToModify: null
            editAreaWidth: editAreaWidth

  _selectionInScope: (selection) =>
    return false if not selection?
    editable = @_editableNode()
    return false if not editable?
    return (editable.contains(selection.anchorNode) and
            editable.contains(selection.focusNode))

  CONTENT_PADDING: 15

  _getToolbarPos: (referenceRect) =>

    TOP_PADDING = 10

    BORDER_RADIUS_PADDING = 15

    editArea = @_editableNode().getBoundingClientRect()

    calcLeft = (referenceRect.left - editArea.left) + referenceRect.width/2
    calcLeft = Math.min(Math.max(calcLeft, @CONTENT_PADDING+BORDER_RADIUS_PADDING), editArea.width - BORDER_RADIUS_PADDING)

    calcTop = referenceRect.top - editArea.top - 48
    toolbarPos = "above"
    if calcTop < TOP_PADDING
      calcTop = referenceRect.top - editArea.top + referenceRect.height + TOP_PADDING + 4
      toolbarPos = "below"

    return [calcLeft, calcTop, editArea.width, toolbarPos]

  _hideToolbar: =>
    if not @_focusedOnToolbar() and @state.toolbarVisible
      @setState toolbarVisible: false

  _focusedOnToolbar: =>
    React.findDOMNode(@refs.floatingToolbar)?.contains(document.activeElement)

  # This needs to be in the contenteditable area because we need to first
  # restore the selection before calling the `execCommand`
  #
  # If the url is empty, that means we want to remove the url.
  _onSaveUrl: (url, linkToModify) =>
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

  _setupLinkHoverListeners: =>
    HOVER_IN_DELAY = 250
    HOVER_OUT_DELAY = 1000
    @_links = {}
    links =  @_getAllLinks()
    return if links.length is 0
    links.forEach (link) =>
      link.hoverId = genLinkId()
      @_links[link.hoverId] = {}

      enterListener = (event) =>
        @_clearLinkTimeouts()
        @_linkHoveringOver = link
        @_links[link.hoverId].enterTimeout = setTimeout =>
          @_refreshToolbarState()
        , HOVER_IN_DELAY

      leaveListener = (event) =>
        @_clearLinkTimeouts()
        @_linkHoveringOver = null
        @_links[link.hoverId].leaveTimeout = setTimeout =>
          return if @refs.floatingToolbar.isHovering
          @_refreshToolbarState()
        , HOVER_OUT_DELAY

      link.addEventListener "mouseenter", enterListener
      link.addEventListener "mouseleave", leaveListener
      @_links[link.hoverId].link = link
      @_links[link.hoverId].enterListener = enterListener
      @_links[link.hoverId].leaveListener = leaveListener

  _clearLinkTimeouts: =>
    for hoverId, linkData of @_links
      clearTimeout(linkData.enterTimeout) if linkData.enterTimeout?
      clearTimeout(linkData.leaveTimeout) if linkData.leaveTimeout?

  _onTooltipMouseEnter: =>
    clearTimeout(@_clearTooltipTimeout) if @_clearTooltipTimeout?

  _onTooltipMouseLeave: =>
    @_clearTooltipTimeout = setTimeout =>
      @_refreshToolbarState()
    , 500

  _teardownLinkHoverListeners: =>
    for hoverId, linkData of @_links
      clearTimeout linkData.enterTimeout
      clearTimeout linkData.leaveTimeout
      linkData.link.removeEventListener "mouseenter", linkData.enterListener
      linkData.link.removeEventListener "mouseleave", linkData.leaveListener
    @_links = {}



  ####### CLEAN PASTE #########

  _onPaste: (evt) =>
    return if evt.clipboardData.items.length is 0
    evt.preventDefault()

    # If the pasteboard has a file on it, stream it to a teporary
    # file and fire our `onFilePaste` event.
    item = evt.clipboardData.items[0]

    if item.kind is 'file' and @props.onFilePaste
      blob = item.getAsFile()
      ext = {'image/png': '.png', 'image/jpg': '.jpg', 'image/tiff': '.tiff'}[item.type] ? ''
      temp = require 'temp'
      path = require 'path'
      fs = require 'fs'

      reader = new FileReader()
      reader.addEventListener 'loadend', =>
        buffer = new Buffer(new Uint8Array(reader.result))
        tmpFolder = temp.path('-nylas-attachment')
        tmpPath = path.join(tmpFolder, "Pasted File#{ext}")
        fs.mkdir tmpFolder, =>
          fs.writeFile tmpPath, buffer, (err) =>
            @props.onFilePaste(tmpPath)
      reader.readAsArrayBuffer(blob)

    else
      # Look for text/html in any of the clipboard items and fall
      # back to text/plain.
      inputText = evt.clipboardData.getData("text/html") ? ""
      type = "text/html"
      if inputText.length is 0
        inputText = evt.clipboardData.getData("text/plain") ? ""
        type = "text/plain"

      if inputText.length > 0
        cleanHtml = @_sanitizeInput(inputText, type)
        document.execCommand("insertHTML", false, cleanHtml)
        @_selectionManuallyChanged = true

    return

  # This is used primarily when pasting text in
  _sanitizeInput: (inputText="", type="text/html") =>
    if type is "text/plain"
      inputText = Utils.encodeHTMLEntities(inputText)
      inputText = inputText.replace(/[\r\n]|&#1[03];/g, "<br/>").
                            replace(/\s\s/g, " &nbsp;")
    else
      inputText = sanitizeHtml inputText.replace(/[\n\r]/g, "<br/>"),
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

      # We sanitized everything and convert all whitespace-inducing
      # elements into <p> tags. We want to de-wrap <p> tags and replace
      # with two line breaks instead.
      inputText = inputText.replace(/<p[\s\S]*?>/gim, "").
                            replace(/<\/p>/gi, "<br/>")

      # We never want more then 2 line breaks in a row.
      # https://regex101.com/r/gF6bF4/4
      inputText = inputText.replace(/(<br\s*\/?>\s*){3,}/g, "<br/><br/>")

      # We never want to keep leading and trailing <brs>, since the user
      # would have started a new paragraph themselves if they wanted space
      # before what they paste.
      # BAD:    "<p>begins at<br>12AM</p>" => "<br><br>begins at<br>12AM<br><br>"
      # Better: "<p>begins at<br>12AM</p>" => "begins at<br>12"
      inputText = inputText.replace(/^(<br ?\/>)+/, '')
      inputText = inputText.replace(/(<br ?\/>)+$/, '')

    return inputText


  ####### QUOTED TEXT #########

  _onToggleQuotedText: =>
    @props.onChangeMode?(showQuotedText: !@props.mode?.showQuotedText)

  _quotedTextClasses: => classNames
    "quoted-text-control": true
    "no-quoted-text": @_htmlQuotedTextStart() is -1
    "show-quoted-text": @props.mode?.showQuotedText

  _htmlQuotedTextStart: =>
    @props.html.search(/(<br\/?>)?(<br\/?>)?<[^>]*gmail_quote/)

  _removeQuotedTextFromHTML: (html) =>
    quoteStart = @_htmlQuotedTextStart()
    if quoteStart is -1 then return html
    else return html.substr(0, quoteStart)

  _addQuotedTextToHTML: (innerHTML) =>
    quoteStart = @_htmlQuotedTextStart()
    if quoteStart is -1 then return innerHTML
    else return (innerHTML + @props.html.substr(quoteStart))


module.exports = ContenteditableComponent
