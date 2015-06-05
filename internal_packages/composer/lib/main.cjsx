_ = require 'underscore'
React = require 'react'

{NamespaceStore,
 DatabaseStore,
 Message,
 ComponentRegistry,
 WorkspaceStore} = require('nylas-exports')
ComposeButton = require('./compose-button')
ComposerView = require('./composer-view')


class ComposerWithWindowProps extends React.Component
  @displayName: 'ComposerWithWindowProps'
  @containerRequired: false

  constructor: (@props) ->
    @state = atom.getWindowProps()

  componentDidMount: ->
    @unlisten = atom.onWindowPropsReceived (windowProps) =>
      {errorMessage} = windowProps
      @_showInitialErrorDialog(errorMessage) if errorMessage
      @setState(windowProps)

  componentWillUnmount: ->
    @unlisten()

  render: ->
    <div className="composer-full-window">
      <ComposerView mode="fullwindow" localId={@state.draftLocalId} />
    </div>

  _showInitialErrorDialog: (msg) ->
    remote = require('remote')
    dialog = remote.require('dialog')
    dialog.showMessageBox remote.getCurrentWindow(), {
      type: 'warning'
      buttons: ['Okay'],
      message: "Error"
      detail: msg
    }

module.exports =
  activate: (@state={}) ->
    atom.registerHotWindow
      windowType: 'composer'
      replenishNum: 2

    # Register our composer as the app-wide Composer
    ComponentRegistry.register ComposerView,
      role: 'Composer'

    if atom.isMainWindow()
      ComponentRegistry.register ComposeButton,
        location: WorkspaceStore.Location.RootSidebar.Toolbar
    else
      atom.getCurrentWindow().setMinimumSize(600, 400)
      WorkspaceStore.defineSheet 'Main', {root: true},
        list: ['Center']
      ComponentRegistry.register ComposerWithWindowProps,
        location: WorkspaceStore.Location.Center

  deactivate: ->
    atom.unregisterHotWindow('composer')
    ComponentRegistry.unregister(ComposerView)
    ComponentRegistry.unregister(ComposeButton)
    ComponentRegistry.unregister(ComposerWithWindowProps)

  serialize: -> @state
