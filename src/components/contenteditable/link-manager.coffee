_ = require 'underscore'
{RegExpUtils, DOMUtils, ContenteditableExtension} = require 'nylas-exports'
LinkEditor = require './link-editor'

class LinkManager extends ContenteditableExtension
  @keyCommandHandlers: =>
    "contenteditable:insert-link": @_onInsertLink

  @toolbarButtons: =>
    [{
      className: "btn-link"
      onClick: @_onInsertLink
      tooltip: "Edit Link"
      iconUrl: null # Defined in the css of btn-link
    }]

  # By default, if you're typing next to an existing anchor tag, it won't
  # continue the anchor text. This is important for us since we want you
  # to be able to select and then override the existing anchor text with
  # something new.
  @onContentChanged: ({editor, mutations}) =>
    sel = editor.currentSelection()
    if sel.anchorNode and sel.isCollapsed
      node = sel.anchorNode
      sibling = node.previousSibling

      return if not sibling
      return if sel.anchorOffset > 1
      return if node.nodeType isnt Node.TEXT_NODE
      return if sibling.nodeName isnt "A"
      return if /^\s+/.test(node.data)
      return if RegExpUtils.punctuation(exclude: ['\\-', '_']).test(node.data[0])

      node.splitText(1) if node.data.length > 1
      sibling.appendChild(node)
      sibling.normalize()
      text = DOMUtils.findLastTextNode(sibling)
      editor.select(text, text.length, text, text.length)

  @toolbarComponentConfig: ({toolbarState}) =>
    return null if toolbarState.dragging or toolbarState.doubleDown

    linkToModify = null

    if not linkToModify and toolbarState.selectionSnapshot
      linkToModify = @_linkAtCursor(toolbarState)

    return null if not linkToModify

    return {
      component: LinkEditor
      props:
        onSaveUrl: (url, linkToModify) =>
          toolbarState.atomicEdit(@_onSaveUrl, {url, linkToModify})
        onDoneWithLink: => toolbarState.atomicEdit(@_onDoneWithLink)
        linkToModify: linkToModify
        focusOnMount: @_shouldFocusOnMount(toolbarState)
      locationRefNode: linkToModify
      width: @_linkWidth(linkToModify)
      height: 34
    }

  @_shouldFocusOnMount: (toolbarState) ->
    not toolbarState.selectionSnapshot.isCollapsed

  @_linkWidth: (linkToModify) ->
    href = linkToModify?.getAttribute?('href') ? ""
    WIDTH_PER_CHAR = 8
    return Math.max(href.length * WIDTH_PER_CHAR + 95, 210)

  @_linkAtCursor: (toolbarState) ->
    if toolbarState.selectionSnapshot.isCollapsed
      anchor = toolbarState.selectionSnapshot.anchorNode
      return DOMUtils.closest(anchor, 'a, n1-prompt-link')
    else
      anchor = toolbarState.selectionSnapshot.anchorNode
      focus = toolbarState.selectionSnapshot.anchorNode
      aPrompt = DOMUtils.closest(anchor, 'n1-prompt-link')
      fPrompt = DOMUtils.closest(focus, 'n1-prompt-link')
      if aPrompt and fPrompt and aPrompt is fPrompt
        aTag = DOMUtils.closest(aPrompt, 'a')
        return aTag ? aPrompt
      else return null

  ## TODO FIXME: Unfortunately, the keyCommandHandler fires before the
  # Contentedtiable onKeyDown.
  #
  # Normally this wouldn't matter, but when `_onInsertLink` runs it will
  # focus on the input box of the link editor.
  #
  # If onKeyDown in the Contenteditable runs after this, then
  # `atomicUpdate` will reset the selection back to the Contenteditable.
  # This process blurs the link input, which causes the LinkInput to close
  # and attempt to set or clear the link. The net effect is that the link
  # insertion appears to not work via keyboard commands.
  #
  # This would not be a problem if the rendering of the Toolbar happened
  # at the same time as the Contenteditable's render cycle. Unfortunatley
  # since the Contenteditable shouldn't re-render on all Selection
  # changes, while the Toolbar should, these are out of sync.
  #
  # The temporary fix is adding a _.defer block to change the ordering of
  # these keyboard events.
  @_onInsertLink: ({editor, event}) -> _.defer ->
    if editor.currentSelection().isCollapsed
      html = "<n1-prompt-link>link text</n1-prompt-link>"
      editor.insertHTML(html, selectInsertion: true)
    else
      editor.wrapSelection("n1-prompt-link")

  @_onDoneWithLink: ({editor}) ->
    for node in editor.rootNode.querySelectorAll("n1-prompt-link")
      editor.unwrapNodeAndSelectAll(node)

  @_onSaveUrl: ({editor, url, linkToModify}) ->
    if linkToModify?
      equivalentNode = DOMUtils.findSimilarNodeAtIndex(editor.rootNode, linkToModify, 0)
      return unless equivalentNode?
      return if linkToModify.getAttribute?('href')?.trim() is url.trim()
      toSelect = equivalentNode
    else
      # When atomicEdit gets run, the exportedSelection is already restored to
      # the last saved exportedSelection state. Any operation we perform will
      # apply to the last saved exportedSelection state.
      toSelect = null

    if url.trim().length is 0
      if toSelect then editor.select(toSelect).unlink()
      else editor.unlink()
    else
      if toSelect then editor.select(toSelect).createLink(url)
      else editor.createLink(url)
    for node in editor.rootNode.querySelectorAll("n1-prompt-link")
      editor.unwrapNodeAndSelectAll(node)

module.exports = LinkManager
