_ = require 'underscore'
React = require 'react'

{AccountStore,
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
      @setState(windowProps)
      if errorMessage
        @_showInitialErrorDialog(errorMessage)

  componentWillUnmount: ->
    @unlisten?()

  render: ->
    <div className="composer-full-window">
      <ComposerView mode="fullwindow" draftClientId={@state.draftClientId} />
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
    # Register our composer as the window-wide Composer
    ComponentRegistry.register ComposerView,
      role: 'Composer'

    if atom.isMainWindow()
      atom.registerHotWindow
        windowType: 'composer'
        replenishNum: 2

      ComponentRegistry.register ComposeButton,
        location: WorkspaceStore.Location.RootSidebar.Toolbar
    else
      atom.getCurrentWindow().setMinimumSize(480, 400)
      WorkspaceStore.defineSheet 'Main', {root: true},
        popout: ['Center']

      ComponentRegistry.register ComposerWithWindowProps,
        location: WorkspaceStore.Location.Center

  deactivate: ->
    if atom.isMainWindow()
      atom.unregisterHotWindow('composer')
    ComponentRegistry.unregister(ComposerView)
    ComponentRegistry.unregister(ComposeButton)
    ComponentRegistry.unregister(ComposerWithWindowProps)

  serialize: -> @state
