{ComponentRegistry,
 WorkspaceStore,
 Actions} = require "nylas-exports"
{RetinaImg} = require 'nylas-component-kit'
React = require "react"
_ = require "underscore"

class ModeToggle extends React.Component
  @displayName: 'ModeToggle'

  constructor: (@props) ->
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unsubscriber = WorkspaceStore.listen(@_onStateChanged)
    @_mounted = true

  componentWillUnmount: =>
    @_mounted = false
    @_unsubscriber?()

  render: =>
    return <div></div> unless @state.visible

    <button className="btn btn-toolbar mode-toggle mode-#{@state.mode}"
         style={order:500}
         onClick={@_onToggleMode}>
      <RetinaImg
        name="toolbar-icon-toggle-pane.png"
        mode={RetinaImg.Mode.ContentIsMask}
        onClick={@_onToggleMode}  />
    </button>

  _onStateChanged: =>
    # We need to keep track of this because our parent unmounts us in the same
    # event listener cycle that we receive the event in. ie:
    #
    #   for listener in listeners
    #      # 1. workspaceView remove left column
    #      # ---- Mode toggle unmounts, listeners array mutated in place
    #      # 2. ModeToggle update
    return unless @_mounted
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    rootModes = WorkspaceStore.rootSheet().supportedModes
    rootVisible = WorkspaceStore.rootSheet() is WorkspaceStore.topSheet()

    mode: WorkspaceStore.preferredLayoutMode()
    visible: rootVisible and rootModes and rootModes.length > 1

  _onToggleMode: =>
    if @state.mode is 'list'
      atom.config.set('core.workspace.mode', 'split')
    else
      atom.config.set('core.workspace.mode', 'list')
    return


module.exports = ModeToggle
