React = require 'react'

class DisclosureTriangle extends React.Component
  @displayName: 'DisclosureTriangle'

  @propTypes:
    collapsed: React.PropTypes.bool
    visible: React.PropTypes.bool
    onToggleCollapsed: React.PropTypes.func

  @defaultProps:
    onToggleCollapsed: ->

  render: ->
    classnames = "disclosure-triangle"
    classnames += " visible" if @props.visible
    classnames += " collapsed" if @props.collapsed
    <div className={classnames} onClick={@props.onToggleCollapsed}><div></div></div>

module.exports = DisclosureTriangle
