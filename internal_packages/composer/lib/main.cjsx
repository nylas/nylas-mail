_ = require 'underscore-plus'
React = require 'react'

{NamespaceStore,
 DatabaseStore,
 Message,
 ComponentRegistry,
 WorkspaceStore} = require('inbox-exports')
NewComposeButton = require('./new-compose-button')
ComposerView = require('./composer-view')

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->

    atom.registerHotWindow
      windowType: "composer"
      replenishNum: 2

    # Register our composer as the app-wide Composer
    ComponentRegistry.register
      name: 'Composer'
      view: ComposerView

    if atom.isMainWindow()
      @_activateComposeButton()
    else
      windowProps = atom.getLoadSettings().windowProps ? {}
      @refreshWindowProps(windowProps)

  refreshWindowProps: (windowProps) ->
    return unless windowProps.createNew

    if @item? then return # Activate once
    @item = document.createElement("div")
    @item.setAttribute("id", "composer-full-window")
    @item.setAttribute("class", "composer-full-window")
    document.body.appendChild(@item)

    @_prepareDraft(windowProps).then (draftLocalId) =>
      React.render(
        <ComposerView mode="fullwindow" localId={draftLocalId} />, @item
      )
      if windowProps.errorMessage
        @_showInitialErrorDialog(windowProps.errorMessage)
    .catch (error) ->
      console.error(error.stack)

  deactivate: ->
    if atom.isMainWindow()
      React.unmountComponentAtNode(@new_compose_button)
      @new_compose_button.remove()
      @new_compose_button = null
    else
      React.unmountComponentAtNode(@item)
      @item.remove()
      @item = null

  serialize: -> @state

  # This logic used to be in the DraftStore (which is where it should be). It
  # got moved here becaues of an obscure atom-shell/Chrome bug whereby database
  # requests firing right before the new-window loaded would cause the
  # new-window to load with about:blank instead of its contents. By moving the
  # DB logic here, we can get around this.
  _prepareDraft: ({draftLocalId, draftInitialJSON}={}) ->
    # The NamespaceStore isn't set yet in the new window, populate it first.
    NamespaceStore.populateItems().then ->
      new Promise (resolve, reject) ->
        if draftLocalId?
          resolve(draftLocalId)
        else
          # Create a new draft
          draft = new Message
            body: ""
            from: [NamespaceStore.current().me()]
            date: (new Date)
            draft: true
            pristine: true
            namespaceId: NamespaceStore.current().id
          # If initial JSON was provided, apply it to the new model.
          # This is used to apply the values in mailto: links to new drafts
          if draftInitialJSON
            draft.fromJSON(draftInitialJSON)

          DatabaseStore.persistModel(draft).then ->
            DatabaseStore.localIdForModel(draft).then(resolve).catch(reject)
          .catch(reject)

  _activateComposeButton: ->
    ComponentRegistry.register
      view: NewComposeButton
      name: 'NewComposeButton'
      location: WorkspaceStore.Location.RootSidebar.Toolbar

  _showInitialErrorDialog: (msg) ->
    remote = require('remote')
    dialog = remote.require('dialog')
    dialog.showMessageBox remote.getCurrentWindow(), {
      type: 'warning'
      buttons: ['Okay'],
      message: "Error"
      detail: msg
    }
