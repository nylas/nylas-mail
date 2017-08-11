React = require 'react'

class DisclosureTriangle extends React.Component
  @displayName: 'DisclosureTriangle'

  @propTypes:
    collapsed: React.PropTypes.bool
    visible: React.PropTypes.bool
    onCollapseToggled: React.PropTypes.func

  @defaultProps:
    onCollapseToggled: ->

  render: ->
    classnames = "disclosure-triangle"
    classnames += " visible" if @props.visible
    classnames += " collapsed" if @props.collapsed
    <div className={classnames} onClick={@props.onCollapseToggled}><div></div></div>

module.exports = DisclosureTriangle
