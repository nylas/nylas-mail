RetinaImg = require './retina-img'
{Utils} = require 'nylas-exports'

React = require 'react'
class ButtonDropdown extends React.Component
  @displayName: "MessageControls"
  @propTypes:
    primaryItem: React.PropTypes.element
    primaryClick: React.PropTypes.func
    menu: React.PropTypes.element

  constructor: (@props) ->
    @state = showing: false

  render: =>
    classnames = "button-dropdown #{@props.className ? ''}"
    classnames += "open" if @state.showing

    <div ref="button" onBlur={@_onBlur} tabIndex={999} className={classnames}>
      <div className="primary-item" onClick={@props.primaryClick}>
        {@props.primaryItem}
      </div>
      <div className="secondary-picker" onClick={@_toggleDropdown}>
        <RetinaImg name={"icon-thread-disclosure.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
      <div className="secondary-items">
        {@props.menu}
      </div>
    </div>

  _toggleDropdown: =>
    @setState showing: !@state.showing

  _onBlur: (event) =>
    target = event.nativeEvent.relatedTarget
    if target? and React.findDOMNode(@refs.button).contains(target)
      return
    @setState showing: false

module.exports = ButtonDropdown
