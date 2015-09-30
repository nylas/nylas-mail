React = require 'react'

# Public: A small React component which renders as a horizontal on/off switch.
# Provide it with `onChange` and `checked` props just like a checkbox:
#
# ```
# <Switch onChange={@_onToggleChecked} checked={@state.form.isChecked} />
# ```
#
class Switch extends React.Component
  @propTypes:
    checked: React.PropTypes.bool.isRequired
    onChange: React.PropTypes.func.isRequired

  constructor: (@props) ->

  render: =>
    classnames = "slide-switch"
    if @props.checked
      classnames += " active"

    <div className={classnames} onClick={@props.onChange}>
      <div className="handle"></div>
    </div>

module.exports = Switch
