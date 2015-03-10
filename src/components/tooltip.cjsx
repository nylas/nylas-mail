_ = require 'underscore-plus'
React = require 'react/addons'

###
The Tooltip component displays a consistent hovering tooltip for use when
extra context information is required.
###

module.exports =
Tooltip = React.createClass
  render: ->
    <div className="tooltip" style={@_styles()}>{@props.children}</div>

  _styles: ->
    @props.modifierElement
