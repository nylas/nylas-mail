RetinaImg = require './retina-img'
{Utils} = require 'nylas-exports'

React = require 'react'
class ButtonDropdown extends React.Component
  @displayName: "ButtonDropdown"
  @propTypes:
    primaryItem: React.PropTypes.element
    primaryClick: React.PropTypes.func
    bordered: React.PropTypes.bool
    menu: React.PropTypes.element
    style: React.PropTypes.object
    closeOnMenuClick: React.PropTypes.bool

  @defaultProps:
    style: {}

  constructor: (@props) ->
    @state = showing: false

  render: =>
    classnames = "button-dropdown #{@props.className ? ''}"
    classnames += " open" if @state.showing
    classnames += " bordered" if @props.bordered isnt false

    if @props.primaryClick
      <div ref="button" onBlur={@_onBlur} tabIndex={999} className={classnames} style={@props.style}>
        <div className="primary-item"
             title={@props.primaryTitle ? ""}
             onClick={@props.primaryClick}>
          {@props.primaryItem}
        </div>
        <div className="secondary-picker" onClick={@toggleDropdown}>
          <RetinaImg name={"icon-thread-disclosure.png"} mode={RetinaImg.Mode.ContentIsMask}/>
        </div>
        <div className="secondary-items" onMouseDown={@_onMenuClick}>
          {@props.menu}
        </div>
      </div>
    else
      <div ref="button" onBlur={@_onBlur} tabIndex={999} className={classnames} style={@props.style}>
        <div className="only-item"
             title={@props.primaryTitle ? ""}
             onClick={@toggleDropdown}>
          {@props.primaryItem}
          <RetinaImg name={"icon-thread-disclosure.png"} style={marginLeft:12} mode={RetinaImg.Mode.ContentIsMask}/>
        </div>
        <div className="secondary-items left" onMouseDown={@_onMenuClick}>
          {@props.menu}
        </div>
      </div>

  toggleDropdown: =>
    @setState(showing: !@state.showing)

  _onMenuClick: (event) =>
    if @props.closeOnMenuClick
      @setState showing: false

  _onBlur: (event) =>
    target = event.nativeEvent.relatedTarget
    if target? and React.findDOMNode(@refs.button).contains(target)
      return
    @setState(showing: false)

module.exports = ButtonDropdown
