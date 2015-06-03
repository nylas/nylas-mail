_ = require 'underscore'
React = require 'react'

{NamespaceStore,
 DatabaseStore,
 Message,
 ComponentRegistry,
 WorkspaceStore} = require('nylas-exports')
NewComposeButton = require('./new-compose-button')
ComposerView = require('./composer-view')

module.exports =

  activate: (@state={}) ->
    atom.registerHotWindow
      windowType: "composer"
      replenishNum: 2

    # Register our composer as the app-wide Composer
    ComponentRegistry.register ComposerView,
      role: 'Composer'

    if atom.isMainWindow()
      ComponentRegistry.register NewComposeButton,
        location: WorkspaceStore.Location.RootSidebar.Toolbar
    else
      @_setupContainer()

  windowPropsReceived: ({draftLocalId, errorMessage}) ->
    return unless @_container
    React.render(
      <ComposerView mode="fullwindow" localId={draftLocalId} />, @_container
    )
    if errorMessage
      @_showInitialErrorDialog(errorMessage)

  deactivate: ->
    ComponentRegistry.unregister(ComposerView)
    if atom.isMainWindow()
      ComponentRegistry.unregister(NewComposeButton)

  serialize: -> @state

  _setupContainer: ->
    if @_container? then return # Activate once
    @_container = document.createElement("div")
    @_container.setAttribute("id", "composer-full-window")
    @_container.setAttribute("class", "composer-full-window")
    document.body.appendChild(@_container)

  _showInitialErrorDialog: (msg) ->
    remote = require('remote')
    dialog = remote.require('dialog')
    dialog.showMessageBox remote.getCurrentWindow(), {
      type: 'warning'
      buttons: ['Okay'],
      message: "Error"
      detail: msg
    }
