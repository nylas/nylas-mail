React = require 'react'
PropTypes = require 'prop-types'

class DisclosureTriangle extends React.Component
  @displayName: 'DisclosureTriangle'

  @propTypes:
    collapsed: PropTypes.bool
    visible: PropTypes.bool
    onCollapseToggled: PropTypes.func

  @defaultProps:
    onCollapseToggled: ->

  render: ->
    classnames = "disclosure-triangle"
    classnames += " visible" if @props.visible
    classnames += " collapsed" if @props.collapsed
    <div className={classnames} onClick={@props.onCollapseToggled}><div></div></div>

module.exports = DisclosureTriangle
