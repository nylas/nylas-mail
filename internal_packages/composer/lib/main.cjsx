_ = require 'underscore-plus'
React = require 'react'
ipc = require 'ipc'

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
    # Register our composer as the app-wide Composer
    ComponentRegistry.register
      name: 'Composer'
      view: ComposerView

    if atom.state.mode is 'editor'
      @_activateComposeButton()

    else
      if @item? then return # Activate once
      @item = document.createElement("div")
      @item.setAttribute("id", "composer-full-window")
      @item.setAttribute("class", "composer-full-window")
      document.body.appendChild(@item)

      component = React.render(<ComposerView mode="fullwindow" />, @item)

      # Wait for the remaining state to be passed into the window
      # from our parent. We need to wait for state because the windows are
      # preloaded so they open instantly, so we don't have data initially
      ipc.on 'composer-state', (optionsJSON) =>
        options = JSON.parse(optionsJSON)
        @_createDraft(options).then (draftLocalId) =>
          component.setProps {localId: draftLocalId}, =>
            @_showInitialErrorDialog(options.error)  if options.error?

        .catch (error) -> console.error(error)

  deactivate: ->
    if atom.state.mode is 'composer'
      React.unmountComponentAtNode(@item)
      @item.remove()
      @item = null
    else
      React.unmountComponentAtNode(@new_compose_button)
      @new_compose_button.remove()
      @new_compose_button = null

  serialize: -> @state

  # This logic used to be in the DraftStore (which is where it should be). It
  # got moved here becaues of an obscure atom-shell/Chrome bug whereby database
  # requests firing right before the new-window loaded would cause the
  # new-window to load with about:blank instead of its contents. By moving the
  # DB logic here, we can get around this.
  _createDraft: ({draftLocalId, draftInitialJSON}) ->
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
