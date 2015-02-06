React = require 'react'

module.exports =
ContenteditableToolbar = React.createClass
  render: ->
    style =
      display: @state.show and 'initial' or 'none'
    <div className="compose-toolbar-wrap" onBlur={@onBlur}>
      <button className="btn btn-icon btn-formatting"
        onClick={=> @setState { show: !@state.show }}
      ><i className="fa fa-font"></i></button>
      <div ref="toolbar" className="compose-toolbar" style={style}>
        <button className="btn btn-bold" onClick={@onClick} data-command-name="bold"><strong>B</strong></button>
        <button className="btn btn-italic" onClick={@onClick} data-command-name="italic"><em>I</em></button>
        <button className="btn btn-underline" onClick={@onClick} data-command-name="underline"><span style={'textDecoration': 'underline'}>U</span></button>
      </div>
    </div>

  getInitialState: ->
    show: false

  componentDidUpdate: (lastProps, lastState) ->
    if !lastState.show and @state.show
      @refs.toolbar.getDOMNode().focus()

  onClick: (event) ->
    cmd = event.currentTarget.getAttribute 'data-command-name'
    document.execCommand(cmd, false, null)
    true

  onBlur: (event) ->
    target = event.nativeEvent.relatedTarget
    if target? and target.getAttribute 'data-command-name'
      return
    @setState
      show: false
