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
    @state = NylasEnv.getWindowProps()

  componentDidMount: ->
    @unlisten = NylasEnv.onWindowPropsReceived (windowProps) =>
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
    {remote} = require('electron')
    dialog = remote.require('dialog')
    # We delay so the view has time to update the restored draft. If we
    # don't delay the modal may come up in a state where the draft looks
    # like it hasn't been restored or has been lost.
    _.delay ->
      dialog.showMessageBox remote.getCurrentWindow(), {
        type: 'warning'
        buttons: ['Okay'],
        message: "Error"
        detail: msg
      }
    , 100

module.exports =
  activate: (@state={}) ->
    # Register our composer as the window-wide Composer
    ComponentRegistry.register ComposerView,
      role: 'Composer'

    if NylasEnv.isMainWindow()
      NylasEnv.registerHotWindow
        windowType: 'composer'
        replenishNum: 2

      ComponentRegistry.register ComposeButton,
        location: WorkspaceStore.Location.RootSidebar.Toolbar
    else
      NylasEnv.getCurrentWindow().setMinimumSize(480, 250)
      WorkspaceStore.defineSheet 'Main', {root: true},
        popout: ['Center']

      ComponentRegistry.register ComposerWithWindowProps,
        location: WorkspaceStore.Location.Center

  deactivate: ->
    if NylasEnv.isMainWindow()
      NylasEnv.unregisterHotWindow('composer')
    ComponentRegistry.unregister(ComposerView)
    ComponentRegistry.unregister(ComposeButton)
    ComponentRegistry.unregister(ComposerWithWindowProps)

  serialize: -> @state
