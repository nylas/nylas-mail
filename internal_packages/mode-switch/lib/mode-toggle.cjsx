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
    mode: WorkspaceStore.selectedLayoutMode()

  componentDidMount: ->
    @unsubscribe = WorkspaceStore.listen(@_onStateChanged, @)

  componentWillUnmount: ->
    @unsubscribe?()

  render: ->
    <div className="mode-switch"
         style={order:51, marginTop:10, marginRight:14}
         onClick={@_onToggleMode}>
      <RetinaImg
        name="toolbar-icon-toggle-pane.png"
        onClick={@_onToggleMode}  />
    </div>
  
  _onStateChanged: ->
    @setState
      mode: WorkspaceStore.selectedLayoutMode()

  _onToggleMode: ->
    if @state.mode is 'list'
      Actions.selectLayoutMode('split')
    else
      Actions.selectLayoutMode('list')
