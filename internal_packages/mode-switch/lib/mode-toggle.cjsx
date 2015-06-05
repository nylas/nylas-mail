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
    @unsubscribe = WorkspaceStore.listen(@_onStateChanged, @)

  componentWillUnmount: =>
    @unsubscribe?()

  render: =>
    return <div></div> unless @state.visible

    <div className="mode-toggle mode-#{@state.mode}"
         style={order:51, marginTop:10, marginRight:14}
         onClick={@_onToggleMode}>
      <RetinaImg
        name="toolbar-icon-toggle-pane.png"
        mode={RetinaImg.Mode.ContentIsMask}
        onClick={@_onToggleMode}  />
    </div>

  _onStateChanged: =>
    @setState(@_getStateFromStores())

  _getStateFromStores: =>
    rootModes = WorkspaceStore.rootSheet().supportedModes
    rootVisible = WorkspaceStore.rootSheet() is WorkspaceStore.topSheet()

    mode: WorkspaceStore.layoutMode()
    visible: rootVisible and rootModes and rootModes.length > 1

  _onToggleMode: =>
    if @state.mode is 'list'
      Actions.selectLayoutMode('split')
    else
      Actions.selectLayoutMode('list')


module.exports = ModeToggle
