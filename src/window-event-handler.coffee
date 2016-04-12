path = require 'path'
{$} = require './space-pen-extensions'
_ = require 'underscore'
{Disposable} = require 'event-kit'
{shell, ipcRenderer, remote} = require 'electron'
{Subscriber} = require 'emissary'
fs = require 'fs-plus'
url = require 'url'

# Handles low-level events related to the window.
module.exports =
class WindowEventHandler
  Subscriber.includeInto(this)

  constructor: ->
    @reloadRequested = false
    @unloadCallbacks = []

    _.defer =>
      @showDevModeMessages()

    @subscribe ipcRenderer, 'open-path', (event, pathToOpen) ->
      unless NylasEnv.project?.getPaths().length
        if fs.existsSync(pathToOpen) or fs.existsSync(path.dirname(pathToOpen))
          NylasEnv.project?.setPaths([pathToOpen])

      unless fs.isDirectorySync(pathToOpen)
        NylasEnv.workspace?.open(pathToOpen, {})

    @subscribe ipcRenderer, 'update-available', (event, detail) ->
      NylasEnv.updateAvailable(detail)

    @subscribe ipcRenderer, 'browser-window-focus', ->
      document.body.classList.remove('is-blurred')
      window.dispatchEvent(new Event('browser-window-focus'))

    @subscribe ipcRenderer, 'browser-window-blur', ->
      document.body.classList.add('is-blurred')
      window.dispatchEvent(new Event('browser-window-blur'))

    @subscribe ipcRenderer, 'command', (event, command, args...) ->
      activeElement = document.activeElement
      # Use the workspace element view if body has focus
      if activeElement is document.body and workspaceElement = document.getElementById("nylas-workspace")
        activeElement = workspaceElement
      NylasEnv.commands.dispatch(activeElement, command, args[0])

    @subscribe ipcRenderer, 'scroll-touch-begin', ->
      window.dispatchEvent(new Event('scroll-touch-begin'))

    @subscribe ipcRenderer, 'scroll-touch-end', ->
      window.dispatchEvent(new Event('scroll-touch-end'))

    @subscribe $(window), 'beforeunload', =>
      # Don't hide the window here if we don't want the renderer process to be
      # throttled in case more work needs to be done before closing
      @reloadRequested = false
      return @runUnloadCallbacks()

    @subscribe $(window), 'unload', =>
      NylasEnv.storeWindowDimensions()
      NylasEnv.saveStateAndUnloadWindow()
      NylasEnv.windowEventHandler?.unsubscribe()

    @subscribeToCommand $(window), 'window:toggle-full-screen', ->
      NylasEnv.toggleFullScreen()

    @subscribeToCommand $(window), 'window:close', ->
      NylasEnv.close()

    @subscribeToCommand $(window), 'window:reload', =>
      @reloadRequested = true
      NylasEnv.reload()

    @subscribeToCommand $(window), 'window:toggle-dev-tools', ->
      NylasEnv.toggleDevTools()

    @subscribeToCommand $(window), 'window:open-errorlogger-logs', ->
      NylasEnv.errorLogger.openLogs()

    @subscribeToCommand $(window), 'window:toggle-component-regions', ->
      ComponentRegistry = require './component-registry'
      ComponentRegistry.toggleComponentRegions()

    @subscribeToCommand $(window), 'window:toggle-react-remote', ->
      ReactRemote = require './react-remote/react-remote-parent'
      ReactRemote.toggleContainerVisible()

    document.addEventListener 'keydown', @onKeydown

    # "Pinch to zoom" on the Mac gets translated by the system into a
    # "scroll with ctrl key down". To prevent the page from zooming in,
    # prevent default when the ctrlKey is detected.
    document.addEventListener 'mousewheel', ->
      if event.ctrlKey
        event.preventDefault()

    document.addEventListener 'drop', @onDrop
    @subscribe new Disposable =>
      document.removeEventListener('drop', @onDrop)

    document.addEventListener 'dragover', @onDragOver
    @subscribe new Disposable =>
      document.removeEventListener('dragover', @onDragOver)

    @subscribe $(document), 'click', 'a', @openLink

    @subscribe $(document), 'contextmenu', 'input', @openContextualMenuForInput

    # Prevent form submits from changing the current window's URL
    @subscribe $(document), 'submit', 'form', (e) -> e.preventDefault()

    @handleNativeKeybindings()

  addUnloadCallback: (callback) ->
    @unloadCallbacks.push(callback)

  runUnloadCallbacks: ->
    unloadCallbacksRunning = 0
    unloadCallbackComplete = =>
      unloadCallbacksRunning -= 1
      if unloadCallbacksRunning is 0
        @runUnloadFinished()

    for callback in @unloadCallbacks
      returnValue = callback(unloadCallbackComplete)
      if returnValue is false
        unloadCallbacksRunning += 1
      else if returnValue isnt true
        console.warn "You registered an `onBeforeUnload` callback that does not return either exactly `true` or `false`. It returned #{returnValue}", callback

    # In Electron, returning false cancels the close.
    return (unloadCallbacksRunning is 0)

  runUnloadFinished: ->
    {remote} = require('electron')
    _.defer ->
      if remote.getGlobal('application').quitting
        remote.require('app').quit()
      else
        NylasEnv.close()

  # Wire commands that should be handled by Chromium for elements with the
  # `.override-key-bindings` class.
  handleNativeKeybindings: ->
    menu = null
    webContents = NylasEnv.getCurrentWindow().webContents
    bindCommandToAction = (command, action) =>
      @subscribe $(document), command, (event) ->
        unless event.target.webkitMatchesSelector('.override-key-bindings')
          webContents[action]()
        true

    bindCommandToAction('core:copy', 'copy')
    bindCommandToAction('core:cut', 'cut')
    bindCommandToAction('core:paste', 'paste')
    bindCommandToAction('core:paste-and-match-style', 'pasteAndMatchStyle')
    bindCommandToAction('core:undo', 'undo')
    bindCommandToAction('core:redo', 'redo')
    bindCommandToAction('core:select-all', 'selectAll')

  onKeydown: (event) ->
    NylasEnv.keymaps.handleKeyboardEvent(event)

  # Important: even though we don't do anything here, we need to catch the
  # drop event to prevent the browser from navigating the to the "url" of the
  # file and completely leaving the app.
  onDrop: (event) ->
    event.preventDefault()
    event.stopPropagation()

  onDragOver: (event) ->
    event.preventDefault()
    event.stopPropagation()

  openLink: ({href, target, currentTarget}) ->
    if not href
      href = target?.getAttribute('href') or currentTarget?.getAttribute('href')

    return unless href

    return if currentTarget?.closest?('.no-open-link-events')

    schema = url.parse(href).protocol
    return unless schema

    if schema is 'mailto:'
      # We sometimes get mailto URIs that are not escaped properly, or have been only partially escaped.
      # (T1927) Be sure to escape them once, and completely, before we try to open them. This logic
      # *might* apply to http/https as well but it's unclear.
      href = encodeURI(decodeURI(href))
      remote.getGlobal('application').openUrl(href)
    else if schema in ['http:', 'https:', 'tel:']
      shell.openExternal(href)

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
    Menu = remote.require('menu')
    MenuItem = remote.require('menu-item')
    menu = new Menu()

    NylasSpellchecker = require('./nylas-spellchecker')
    NylasSpellchecker.appendSpellingItemsToMenu
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

    if NylasEnv.inDevMode()
      Actions = require './flux/actions'
      Actions.postNotification
        icon: 'fa-flask'
        type: 'developer'
        tag: 'developer'
        sticky: true
        actions: [{label: 'Thanks', id: 'ok', dismisses: true, default: true}]
        message: "N1 is running with debug flags enabled (slower). Packages in
                  ~/.nylas/dev/packages will be loaded. Have fun!"
    else
      console.log("%c Welcome to N1! If you're exploring the source or building a
                   plugin, you should enable debug flags. It's slower, but
                   gives you better exceptions, the debug version of React,
                   and more. Choose %c Developer > Run with Debug Flags %c
                   from the menu. Also, check out https://nylas.com/N1/docs
                   for documentation and sample code!",
                   "background-color: antiquewhite;",
                   "background-color: antiquewhite; font-weight:bold;",
                   "background-color: antiquewhite; font-weight:normal;")
