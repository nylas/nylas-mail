path = require 'path'
_ = require 'underscore'
{Disposable} = require 'event-kit'
{shell, ipcRenderer, remote} = require 'electron'
fs = require 'fs-plus'
url = require 'url'

# Handles low-level events related to the window.
module.exports =
class WindowEventHandler
  constructor: ->
    @unloadCallbacks = []

    _.defer =>
      @showDevModeMessages()

    ipcRenderer.on 'update-available', (event, detail) ->
      NylasEnv.updateAvailable(detail)

    ipcRenderer.on 'browser-window-focus', ->
      document.body.classList.remove('is-blurred')
      window.dispatchEvent(new Event('browser-window-focus'))

    ipcRenderer.on 'browser-window-blur', ->
      document.body.classList.add('is-blurred')
      window.dispatchEvent(new Event('browser-window-blur'))

    ipcRenderer.on 'command', (event, command, args...) ->
      NylasEnv.commands.dispatch(command, args[0])

    ipcRenderer.on 'scroll-touch-begin', ->
      window.dispatchEvent(new Event('scroll-touch-begin'))

    ipcRenderer.on 'scroll-touch-end', ->
      window.dispatchEvent(new Event('scroll-touch-end'))

    window.onbeforeunload = =>
      if NylasEnv.inSpecMode() then return undefined
      # Don't hide the window here if we don't want the renderer process to be
      # throttled in case more work needs to be done before closing

      # In Electron, returning any value other than undefined cancels the close.
      if @runUnloadCallbacks()
        # Good to go! Window will be closing...
        NylasEnv.storeWindowDimensions()
        NylasEnv.saveStateAndUnloadWindow()
        return undefined
      return false

    NylasEnv.commands.add document.body, 'window:toggle-full-screen', ->
      NylasEnv.toggleFullScreen()

    NylasEnv.commands.add document.body, 'window:close', ->
      NylasEnv.close()

    NylasEnv.commands.add document.body, 'window:reload', =>
      NylasEnv.reload()

    NylasEnv.commands.add document.body, 'window:toggle-dev-tools', ->
      NylasEnv.toggleDevTools()

    NylasEnv.commands.add document.body, 'window:open-errorlogger-logs', ->
      NylasEnv.errorLogger.openLogs()

    NylasEnv.commands.add document.body, 'window:toggle-component-regions', ->
      ComponentRegistry = require './registries/component-registry'
      ComponentRegistry.toggleComponentRegions()

    webContents = NylasEnv.getCurrentWindow().webContents
    NylasEnv.commands.add(document.body, 'core:copy', => webContents.copy())
    NylasEnv.commands.add(document.body, 'core:cut', => webContents.cut())
    NylasEnv.commands.add(document.body, 'core:paste', => webContents.paste())
    NylasEnv.commands.add(document.body, 'core:paste-and-match-style', => webContents.pasteAndMatchStyle())
    NylasEnv.commands.add(document.body, 'core:undo', => webContents.undo())
    NylasEnv.commands.add(document.body, 'core:redo', => webContents.redo())
    NylasEnv.commands.add(document.body, 'core:select-all', => webContents.selectAll())

    # "Pinch to zoom" on the Mac gets translated by the system into a
    # "scroll with ctrl key down". To prevent the page from zooming in,
    # prevent default when the ctrlKey is detected.
    document.addEventListener 'mousewheel', ->
      if event.ctrlKey
        event.preventDefault()

    document.addEventListener 'drop', @onDrop

    document.addEventListener 'dragover', @onDragOver

    document.addEventListener 'click', (event) =>
      if event.target.closest('[href]')
        @openLink(event)

    document.addEventListener 'contextmenu', (event) =>
      if event.target.nodeName is 'INPUT'
        @openContextualMenuForInput(event)

    # Prevent form submits from changing the current window's URL
    document.addEventListener 'submit', (event) =>
      if event.target.nodeName is 'FORM'
        event.preventDefault()
        @openContextualMenuForInput(event)

  addUnloadCallback: (callback) ->
    @unloadCallbacks.push(callback)

  removeUnloadCallback: (callback) ->
    @unloadCallbacks = @unloadCallbacks.filter (cb) -> cb isnt callback

  runUnloadCallbacks: ->
    hasReturned = false

    unloadCallbacksRunning = 0
    unloadCallbackComplete = =>
      unloadCallbacksRunning -= 1
      if unloadCallbacksRunning is 0 and hasReturned
        @runUnloadFinished()

    for callback in @unloadCallbacks
      returnValue = callback(unloadCallbackComplete)
      if returnValue is false
        unloadCallbacksRunning += 1
      else if returnValue isnt true
        console.warn "You registered an `onBeforeUnload` callback that does not return either exactly `true` or `false`. It returned #{returnValue}", callback

    # In Electron, returning false cancels the close.
    hasReturned = true
    return (unloadCallbacksRunning is 0)

  runUnloadFinished: ->
    {remote} = require('electron')
    _.defer ->
      if remote.getGlobal('application').isQuitting()
        remote.app.quit()
      else if NylasEnv.isReloading
        NylasEnv.isReloading = false
        NylasEnv.reload()
      else
        NylasEnv.close()

  # Important: even though we don't do anything here, we need to catch the
  # drop event to prevent the browser from navigating the to the "url" of the
  # file and completely leaving the app.
  onDrop: (event) ->
    event.preventDefault()
    event.stopPropagation()

  onDragOver: (event) ->
    event.preventDefault()
    event.stopPropagation()

  resolveHref: (el) ->
    return null unless el
    closestHrefEl = el.closest('[href]')
    return closestHrefEl.getAttribute('href') if closestHrefEl
    return null

  openLink: ({href, target, currentTarget, metaKey}) ->
    if not href
      href = @resolveHref(target || currentTarget)
    return unless href

    return if target?.closest('.no-open-link-events')

    {protocol} = url.parse(href)
    return unless protocol

    if protocol in ['mailto:', 'nylas:']
      # We sometimes get mailto URIs that are not escaped properly, or have been only partially escaped.
      # (T1927) Be sure to escape them once, and completely, before we try to open them. This logic
      # *might* apply to http/https as well but it's unclear.
      href = encodeURI(decodeURI(href))
      remote.getGlobal('application').openUrl(href)
    else if protocol in ['http:', 'https:', 'tel:']
      shell.openExternal(href, activate: !metaKey)

    return

  openContextualMenuForInput: (event) ->
    event.preventDefault()

    return unless event.target.type in ['text', 'password', 'email', 'number', 'range', 'search', 'tel', 'url']
    hasSelectedText = event.target.selectionStart isnt event.target.selectionEnd

    if hasSelectedText
      wordStart = event.target.selectionStart
      wordEnd = event.target.selectionEnd
    else
      wordStart = event.target.value.lastIndexOf(" ", event.target.selectionStart)
      wordStart = 0 if wordStart is -1
      wordEnd = event.target.value.indexOf(" ", event.target.selectionStart)
      wordEnd = event.target.value.length if wordEnd is -1
    word = event.target.value.substr(wordStart, wordEnd - wordStart)

    {remote} = require('electron')
    {Menu, MenuItem} = remote
    menu = new Menu()

    Spellchecker = require('./spellchecker').default
    Spellchecker.appendSpellingItemsToMenu
      menu: menu,
      word: word,
      onCorrect: (correction) =>
        insertionPoint = wordStart + correction.length
        event.target.value = event.target.value.replace(word, correction)
        event.target.setSelectionRange(insertionPoint, insertionPoint)

    menu.append(new MenuItem({
      label: 'Cut'
      enabled: hasSelectedText
      click: => document.execCommand('cut')
    }))
    menu.append(new MenuItem({
      label: 'Copy'
      enabled: hasSelectedText
      click: => document.execCommand('copy')
    }))
    menu.append(new MenuItem({
      label: 'Paste',
      click: => document.execCommand('paste')
    }))
    menu.popup(remote.getCurrentWindow())

  showDevModeMessages: ->
    return unless NylasEnv.isMainWindow()

    if !NylasEnv.inDevMode()
      console.log("%c Welcome to N1! If you're exploring the source or building a
                   plugin, you should enable debug flags. It's slower, but
                   gives you better exceptions, the debug version of React,
                   and more. Choose %c Developer > Run with Debug Flags %c
                   from the menu. Also, check out https://nylas.github.io/N1/docs/
                   for documentation and sample code!",
                   "background-color: antiquewhite;",
                   "background-color: antiquewhite; font-weight:bold;",
                   "background-color: antiquewhite; font-weight:normal;")
