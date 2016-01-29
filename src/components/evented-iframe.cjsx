React = require 'react'
{RegExpUtils}= require 'nylas-exports'
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
    @_subscribeToIFrameEvents()

  componentWillUnmount: =>
    @_unsubscribeFromIFrameEvents()

  ###
  Public: Call this method if you replace the contents of the iframe's document.
  This allows {EventedIframe} to re-attach it's event listeners.
  ###
  documentWasReplaced: =>
    @_unsubscribeFromIFrameEvents()
    @_subscribeToIFrameEvents()

  _unsubscribeFromIFrameEvents: =>
    node = React.findDOMNode(@)
    doc = node.contentDocument
    return unless doc
    doc.removeEventListener('click', @_onIFrameClick)
    doc.removeEventListener('keydown', @_onIFrameKeydown)
    doc.removeEventListener('mousedown', @_onIFrameMouseEvent)
    doc.removeEventListener('mousemove', @_onIFrameMouseEvent)
    doc.removeEventListener('mouseup', @_onIFrameMouseEvent)
    doc.removeEventListener("contextmenu", @_onIFrameContextualMenu)
    if node.contentWindow
      node.contentWindow.removeEventListener('focus', @_onIFrameFocus)
      node.contentWindow.removeEventListener('blur', @_onIFrameBlur)
      node.contentWindow.removeEventListener('resize', @_onIFrameResize)

  _subscribeToIFrameEvents: =>
    node = React.findDOMNode(@)
    doc = node.contentDocument
    _.defer =>
      doc.addEventListener("click", @_onIFrameClick)
      doc.addEventListener("keydown", @_onIFrameKeydown)
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
    node = React.findDOMNode(@)
    node.contentWindow.getSelection().empty()

  _onIFrameFocus: (event) =>
    window.getSelection().empty()

  _onIFrameResize: (event) =>
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

      e.preventDefault()
      NylasEnv.windowEventHandler.openLink(target: target)

  _isBlacklistedHref: (href) ->
    return (new RegExp(/^file:/i)).test(href)

  _onIFrameMouseEvent: (event) =>
    node = React.findDOMNode(@)
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

  _onIFrameKeydown: (event) =>
    return if event.metaKey or event.altKey or event.ctrlKey
    React.findDOMNode(@).dispatchEvent(new KeyboardEvent(event.type, event))

  _onIFrameContextualMenu: (event) =>
    # Build a standard-looking contextual menu with options like "Copy Link",
    # "Copy Image" and "Search Google for 'Bla'"
    event.preventDefault()

    {remote} = require('electron')
    clipboard = require('clipboard')
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')
    NativeImage = require('native-image')
    shell = require('shell')
    path = require('path')
    fs = require('fs')
    menu = new Menu()

    # Menu actions for links
    linkTarget = @_getContainingTarget(event, {with: 'href'})
    if linkTarget
      href = linkTarget.getAttribute('href')
      menu.append(new MenuItem({ label: "Open Link", click:( -> NylasEnv.windowEventHandler.openLink({href}) )}))
      menu.append(new MenuItem({ label: "Copy Link", click:( -> clipboard.writeText(href) )}))
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
            img = NativeImage.createFromDataURL(imageDataURL)
            clipboard.writeImage(img)
          , false)
          img.src = src
      }))
      menu.append(new MenuItem({ type: 'separator' }))

    # Menu actions for text
    text = ""
    selection = React.findDOMNode(@).contentDocument.getSelection()
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
