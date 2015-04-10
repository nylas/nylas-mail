{ComponentRegistry,
 WorkspaceStore,
 Actions} = require "inbox-exports"
{RetinaImg} = require 'ui-components'
React = require "react"
_ = require "underscore-plus"

module.exports =
ModeToggle = React.createClass
  displayName: 'ModeToggle'

  getInitialState: ->
    @_getStateFromStores()

  componentDidMount: ->
    @unsubscribe = WorkspaceStore.listen(@_onStateChanged, @)

  componentWillUnmount: ->
    @unsubscribe?()

  render: ->
    return <div></div> unless @state.visible

    <div className="mode-switch"
         style={order:51, marginTop:10, marginRight:14}
         onClick={@_onToggleMode}>
      <RetinaImg
        name="toolbar-icon-toggle-pane.png"
        onClick={@_onToggleMode}  />
    </div>
  
  _onStateChanged: ->
    @setState(@_getStateFromStores())

  _getStateFromStores: ->
    rootModes = WorkspaceStore.rootSheet().supportedModes
    rootVisible = WorkspaceStore.rootSheet() is WorkspaceStore.topSheet()

    mode: WorkspaceStore.layoutMode()
    visible: rootVisible and rootModes and rootModes.length > 1

  _onToggleMode: ->
    if @state.mode is 'list'
      Actions.selectLayoutMode('split')
    else
      Actions.selectLayoutMode('list')
