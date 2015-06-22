RetinaImg = require './retina-img'
{Utils} = require 'nylas-exports'

React = require 'react'
class ButtonDropdown extends React.Component
  @displayName: "MessageControls"
  @propTypes:
    primaryItem: React.PropTypes.element
    secondaryItems: React.PropTypes.arrayOf(React.PropTypes.element)

  constructor: (@props) ->
    @state = showing: false

  render: =>
    <div ref="button" onBlur={@_onBlur} tabIndex={999} className="#{@props.className ? ''} button-dropdown" >
      <div className="primary-item">
        {@props.primaryItem}
      </div>
      <div className="secondary-picker" onClick={@_toggleDropdown}>
        <RetinaImg name={"icon-thread-disclosure.png"} mode={RetinaImg.Mode.ContentIsMask}/>
      </div>
      <div className="secondary-items" style={display: if @state.showing then "block" else "none"}>
        {@props.secondaryItems.map (item) ->
          <div key={Utils.generateTempId()} className="secondary-item">{item}</div>
        }
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
