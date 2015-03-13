{ComponentRegistry,
 WorkspaceStore,
 Actions} = require "inbox-exports"
{RetinaImg} = require 'ui-components'
React = require "react"
_ = require "underscore-plus"

module.exports =
ModeSwitch = React.createClass
  displayName: 'ModeSwitch'

  getInitialState: ->
    mode: WorkspaceStore.selectedLayoutMode()

  componentDidMount: ->
    @unsubscribe = WorkspaceStore.listen(@_onStateChanged, @)

  componentWillUnmount: ->
    @unsubscribe?()

  render: ->
    knobX = if @state.mode is 'list' then 25 else 41

    # Currently ModeSwitch is an opaque control that is not intended
    # to be styled, hence the fixed margins and positions. If we
    # turn this into a standard component one day, change!
    <div className="mode-switch"
         style={order:51, marginTop:14, marginRight:20}
         onClick={@_onToggleMode}>
      <RetinaImg
        data-mode={'list'}
        name="toolbar-icon-listmode.png"
        active={@state.mode is 'list'}
        onClick={@_onSetMode}
        style={paddingRight:12} />
      <RetinaImg
        name="modeslider-bg.png"/>
      <RetinaImg
        name="modeslider-knob.png"
        className="handle"
        style={top:4, left: knobX}/>
      <RetinaImg 
        data-mode={'split'}
        name="toolbar-icon-splitpanes.png" 
        active={@state.mode is 'split'}
        onClick={@_onSetMode}
        style={paddingLeft:12} />
    </div>
  
  _onStateChanged: ->
    @setState
      mode: WorkspaceStore.selectedLayoutMode()

  _onToggleMode: ->
    if @state.mode is 'list'
      Actions.selectLayoutMode('split')
    else
      Actions.selectLayoutMode('list')

  _onSetMode: (event) ->
    Actions.selectLayoutMode(event.target.dataset.mode)
    event.stopPropagation()
