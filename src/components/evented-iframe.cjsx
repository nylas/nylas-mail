React = require 'react'
ReactDOM = require 'react-dom'
{Utils,
 RegExpUtils,
 IdentityStore,
 SearchableComponentMaker,
 SearchableComponentStore}= require 'nylas-exports'
IFrameSearcher = require('../searchable-components/iframe-searcher').default
url = require 'url'
_ = require "underscore"

###
Public: EventedIFrame is a thin wrapper around the DOM's standard `<iframe>` element.
You should always use EventedIFrame, because it provides important event hooks that
ensure keyboard and mouse events are properly delivered to the application when
fired within iFrames.

```
<div className="file-frame-container">
  <EventedIFrame src={src} />
  <Spinner visible={!@state.ready} />
</div>
```

Any `props` added to the <EventedIFrame> are passed to the iFrame it renders.

Section: Component Kit
###
class EventedIFrame extends React.Component
  @displayName = 'EventedIFrame'

  render: =>
    <iframe seamless="seamless" {...@props} />

  componentDidMount: =>
    if @props.searchable
      @_regionId = Utils.generateTempId()
      @_searchUsub = SearchableComponentStore.listen @_onSearchableStoreChange
      SearchableComponentStore.registerSearchRegion(@_regionId, ReactDOM.findDOMNode(this))
    @_subscribeToIFrameEvents()

  componentWillUnmount: =>
    @_unsubscribeFromIFrameEvents()
    if @props.searchable
      @_searchUsub()
      SearchableComponentStore.unregisterSearchRegion(@_regionId)

  componentDidUpdate: ->
    if @props.searchable
      SearchableComponentStore.registerSearchRegion(@_regionId, ReactDOM.findDOMNode(this))

  shouldComponentUpdate: (nextProps, nextState) =>
    not Utils.isEqualReact(nextProps, @props) or
    not Utils.isEqualReact(nextState, @state)

  ###
  Public: Call this method if you replace the contents of the iframe's document.
  This allows {EventedIframe} to re-attach it's event listeners.
  ###
  didReplaceDocument: =>
    @_unsubscribeFromIFrameEvents()
    @_subscribeToIFrameEvents()

  setHeightQuietly: (height) =>
    @_ignoreNextResize = true
    ReactDOM.findDOMNode(@).height = "#{height}px"

  _onSearchableStoreChange: =>
    return unless @props.searchable
    node = ReactDOM.findDOMNode(@)
    doc = node.contentDocument?.body ? node.contentDocument
    searchIndex = SearchableComponentStore.getCurrentRegionIndex(@_regionId)
    {searchTerm} = SearchableComponentStore.getCurrentSearchData()
    if @lastSearchIndex isnt searchIndex or @lastSearchTerm isnt searchTerm
      IFrameSearcher.highlightSearchInDocument(@_regionId, searchTerm, doc, searchIndex)
    @lastSearchIndex = searchIndex
    @lastSearchTerm = searchTerm

  _unsubscribeFromIFrameEvents: =>
    node = ReactDOM.findDOMNode(@)
    doc = node.contentDocument
    return unless doc
    doc.removeEventListener('click', @_onIFrameClick)
    doc.removeEventListener('keydown', @_onIFrameKeyEvent)
    doc.removeEventListener('keypress', @_onIFrameKeyEvent)
    doc.removeEventListener('keyup', @_onIFrameKeyEvent)
    doc.removeEventListener('mousedown', @_onIFrameMouseEvent)
    doc.removeEventListener('mousemove', @_onIFrameMouseEvent)
    doc.removeEventListener('mouseup', @_onIFrameMouseEvent)
    doc.removeEventListener("contextmenu", @_onIFrameContextualMenu)
    if node.contentWindow
      node.contentWindow.removeEventListener('focus', @_onIFrameFocus)
      node.contentWindow.removeEventListener('blur', @_onIFrameBlur)
      node.contentWindow.removeEventListener('resize', @_onIFrameResize)

  _subscribeToIFrameEvents: =>
    node = ReactDOM.findDOMNode(@)
    doc = node.contentDocument
    _.defer =>
      doc.addEventListener("click", @_onIFrameClick)
      doc.addEventListener("keydown", @_onIFrameKeyEvent)
      doc.addEventListener("keypress", @_onIFrameKeyEvent)
      doc.addEventListener("keyup", @_onIFrameKeyEvent)
      doc.addEventListener("mousedown", @_onIFrameMouseEvent)
      doc.addEventListener("mousemove", @_onIFrameMouseEvent)
      doc.addEventListener("mouseup", @_onIFrameMouseEvent)
      doc.addEventListener("contextmenu", @_onIFrameContextualMenu)
      if node.contentWindow
        node.contentWindow.addEventListener("focus", @_onIFrameFocus)
        node.contentWindow.addEventListener("blur", @_onIFrameBlur)
        node.contentWindow.addEventListener('resize', @_onIFrameResize) if @props.onResize

  _getContainingTarget: (event, options) =>
    target = event.target
    while target? and (target isnt document) and (target isnt window)
      return target if target.getAttribute(options.with)?
      target = target.parentElement
    return null

  _onIFrameBlur: (event) =>
    node = ReactDOM.findDOMNode(@)
    node.contentWindow.getSelection().empty()

  _onIFrameFocus: (event) =>
    window.getSelection().empty()

  _onIFrameResize: (event) =>
    if @_ignoreNextResize
      @_ignoreNextResize = false
      return
    @props.onResize?(event)

  # The iFrame captures events that take place over it, which causes some
  # interesting behaviors. For example, when you drag and release over the
  # iFrame, the mouseup never fires in the parent window.
  _onIFrameClick: (e) =>
    e.stopPropagation()
    target = @_getContainingTarget(e, {with: 'href'})
    if target

      # Sometimes urls can have relative, malformed, or malicious href
      # targets. We test the existence of a valid RFC 3986 scheme and make
      # sure the protocol isn't blacklisted. We never allow `file:` links
      # through.
      rawHref = target.getAttribute('href')

      if @_isBlacklistedHref(rawHref)
        e.preventDefault()
        return

      if not url.parse(rawHref).protocol
        # Check for protocol-relative uri's
        if (new RegExp(/^\/\//)).test(rawHref)
          target.setAttribute('href', "https:#{rawHref}")
        else
          target.setAttribute('href', "http://#{rawHref}")

        rawHref = target.getAttribute('href')

      e.preventDefault()

      # If this is a link to our billing site, attempt single sign on instead of
      # just following the link directly
      if rawHref.startsWith(IdentityStore.URLRoot)
        path = rawHref.split(IdentityStore.URLRoot).pop()
        IdentityStore.fetchSingleSignOnURL(IdentityStore.identity(), path).then (href) =>
          NylasEnv.windowEventHandler.openLink(href: href, metaKey: e.metaKey)
        return

      # It's important to send the raw `href` here instead of the target.
      # The `target` comes from the document context of the iframe, which
      # as of Electron 0.36.9, has different constructor function objects
      # in memory than the main execution context. This means that code
      # like `e.target instanceof Element` will erroneously return false
      # since the `e.target.constructor` and the `Element` function are
      # created in different contexts.
      NylasEnv.windowEventHandler.openLink(href: rawHref, metaKey: e.metaKey)

  _isBlacklistedHref: (href) ->
    return (new RegExp(/^file:/i)).test(href)

  _onIFrameMouseEvent: (event) =>
    node = ReactDOM.findDOMNode(@)
    nodeRect = node.getBoundingClientRect()

    eventAttrs = {}
    for key in Object.keys(event)
      continue if key in ['webkitMovementX', 'webkitMovementY']
      eventAttrs[key] = event[key]

    node.dispatchEvent(new MouseEvent(event.type, _.extend({}, eventAttrs, {
      clientX: event.clientX + nodeRect.left
      clientY: event.clientY + nodeRect.top
      pageX: event.pageX + nodeRect.left
      pageY: event.pageY + nodeRect.top
    })))

  _onIFrameKeyEvent: (event) =>
    return if event.metaKey or event.altKey or event.ctrlKey

    attrs = ['key', 'code','location', 'ctrlKey', 'shiftKey', 'altKey', 'metaKey', 'repeat', 'isComposing', 'charCode', 'keyCode', 'which']
    eventInit = Object.assign({bubbles: true}, _.pick(event, attrs))
    eventInParentDoc = new KeyboardEvent(event.type, eventInit)

    Object.defineProperty(eventInParentDoc, 'which', {value: event.which})

    ReactDOM.findDOMNode(@).dispatchEvent(eventInParentDoc)

  _onIFrameContextualMenu: (event) =>
    # Build a standard-looking contextual menu with options like "Copy Link",
    # "Copy Image" and "Search Google for 'Bla'"
    event.preventDefault()

    {remote, clipboard, shell, nativeImage} = require('electron')
    {Menu, MenuItem} = remote
    path = require('path')
    fs = require('fs')
    menu = new Menu()

    # Menu actions for links
    linkTarget = @_getContainingTarget(event, {with: 'href'})
    if linkTarget
      href = linkTarget.getAttribute('href')
      if href.startsWith('mailto')
        menu.append(new MenuItem({ label: "Compose Message...", click:( -> NylasEnv.windowEventHandler.openLink({href}) )}))
        menu.append(new MenuItem({ label: "Copy Email Address", click:( -> clipboard.writeText(href.split('mailto:').pop()) )}))
      else
        menu.append(new MenuItem({ label: "Open Link", click:( -> NylasEnv.windowEventHandler.openLink({href}) )}))
        menu.append(new MenuItem({ label: "Copy Link Address", click:( -> clipboard.writeText(href) )}))
      menu.append(new MenuItem({ type: 'separator' }))

    # Menu actions for images
    imageTarget = @_getContainingTarget(event, {with: 'src'})
    if imageTarget
      src = imageTarget.getAttribute('src')
      srcFilename = path.basename(src)
      menu.append(new MenuItem({
        label: "Save Image...",
        click: ->
          NylasEnv.showSaveDialog {defaultPath: srcFilename}, (path) ->
            return unless path
            oReq = new XMLHttpRequest()
            oReq.open("GET", src, true)
            oReq.responseType = "arraybuffer"
            oReq.onload = ->
              buffer = new Buffer(new Uint8Array(oReq.response))
              fs.writeFile path, buffer, (err) ->
                shell.showItemInFolder(path)
            oReq.send()
      }))
      menu.append(new MenuItem({
        label: "Copy Image",
        click: ->
          img = new Image()
          img.addEventListener("load", ->
            canvas = document.createElement("canvas")
            canvas.width = img.width
            canvas.height = img.height
            canvas.getContext("2d").drawImage(imageTarget, 0, 0)
            imageDataURL = canvas.toDataURL("image/png")
            img = nativeImage.createFromDataURL(imageDataURL)
            clipboard.writeImage(img)
          , false)
          img.src = src
      }))
      menu.append(new MenuItem({ type: 'separator' }))

    # Menu actions for text
    text = ""
    selection = ReactDOM.findDOMNode(@).contentDocument.getSelection()
    if selection.rangeCount > 0
      range = selection.getRangeAt(0)
      text = range.toString()
    if not text or text.length is 0
      text = (linkTarget ? event.target).innerText
    text = text.trim()

    if text.length > 0
      if text.length > 45
        textPreview = text.substr(0, 42) + "..."
      else
        textPreview = text
      menu.append(new MenuItem({ label: "Copy", click:( -> clipboard.writeText(text) )}))
      menu.append(new MenuItem({ label: "Search Google for '#{textPreview}'", click:( -> shell.openExternal("https://www.google.com/search?q=#{encodeURIComponent(text)}") )}))
      if process.platform is 'darwin'
        menu.append(new MenuItem({ label: "Look Up '#{textPreview}'", click:( -> NylasEnv.getCurrentWindow().showDefinitionForSelection() )}))


    if process.platform is 'darwin'
      menu.append(new MenuItem({ type: 'separator' }))
      # Services menu appears here automatically

    menu.popup(remote.getCurrentWindow())

module.exports = EventedIFrame
