{ComponentRegistry,
 WorkspaceStore,
 Actions} = require "nylas-exports"
{RetinaImg} = require 'nylas-component-kit'
React = require "react"
_ = require "underscore"

class ModeToggle extends React.Component
  @displayName: 'ModeToggle'

  constructor: (@props) ->
    @column = WorkspaceStore.Location.MessageListSidebar
    @state = @_getStateFromStores()

  componentDidMount: =>
    @_unsubscriber = WorkspaceStore.listen(@_onStateChanged)
    @_mounted = true

  componentWillUnmount: =>
    @_mounted = false
    @_unsubscriber?()

  render: =>
    <button
         className="btn btn-toolbar mode-toggle mode-#{@state.hidden}"
         style={order:500}
         title={if @state.hidden then "Show sidebar" else "Hide sidebar"}
         onClick={@_onToggleMode}>
      <RetinaImg
        name="toolbar-person-sidebar.png"
        mode={RetinaImg.Mode.ContentIsMask} />
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
    {hidden: WorkspaceStore.isLocationHidden(@column)}

  _onToggleMode: =>
    Actions.toggleWorkspaceLocationHidden(@column)


module.exports = ModeToggle
