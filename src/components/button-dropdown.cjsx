RetinaImg = require './retina-img'
{Utils} = require 'nylas-exports'
classnames = require 'classnames'

React = require 'react'
ReactDOM = require 'react-dom'
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
    @state = open: false

  render: =>
    classes = classnames
      'button-dropdown': true
      'open open-up': @state.open is 'up'
      'open open-down': @state.open is 'down'
      'bordered': @props.bordered isnt false

    if @props.primaryClick
      <div ref="button" onBlur={@_onBlur} tabIndex={-1} className={"#{classes} #{@props.className ? ''}"} style={@props.style}>
        <div className="primary-item"
             title={@props.primaryTitle ? ""}
             onClick={@props.primaryClick}>
          {@props.primaryItem}
        </div>
        <div className="secondary-picker" onClick={@toggleDropdown}>
          <RetinaImg name={"icon-thread-disclosure.png"} mode={RetinaImg.Mode.ContentIsMask}/>
        </div>
        <div ref="secondaryItems" className="secondary-items" onMouseDown={@_onMenuClick}>
          {@props.menu}
        </div>
      </div>
    else
      <div ref="button" onBlur={@_onBlur} tabIndex={-1} className={"#{classes} #{@props.className ? ''}"} style={@props.style}>
        <div className="only-item"
             title={@props.primaryTitle ? ""}
             onClick={@toggleDropdown}>
          {@props.primaryItem}
          <RetinaImg name={"icon-thread-disclosure.png"} style={marginLeft:12} mode={RetinaImg.Mode.ContentIsMask}/>
        </div>
        <div ref="secondaryItems" className="secondary-items left" onMouseDown={@_onMenuClick}>
          {@props.menu}
        </div>
      </div>

  toggleDropdown: =>
    if @state.open isnt false
      @setState(open: false)
    else
      buttonBottom = ReactDOM.findDOMNode(@).getBoundingClientRect().bottom
      openHeight = ReactDOM.findDOMNode(@refs.secondaryItems).getBoundingClientRect().height
      if buttonBottom + openHeight > window.innerHeight
        @setState(open: 'up')
      else
        @setState(open: 'down')

  _onMenuClick: (event) =>
    if @props.closeOnMenuClick
      @setState open: false

  _onBlur: (event) =>
    target = event.nativeEvent.relatedTarget
    if target? and ReactDOM.findDOMNode(@refs.button).contains(target)
      return
    @setState(open: false)

module.exports = ButtonDropdown
