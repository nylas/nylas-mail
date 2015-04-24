React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry} = require "inbox-exports"

###
Public: A simple wrapper that provides a Flexbox layout with the given direction and style.
Any additional props you set on the Flexbox are rendered.
###
class Flexbox extends React.Component
  @displayName: 'Flexbox'

  ###
  Public: React `props` supported by Flexbox:
  
   - `direction` (optional) A {String} Flexbox direction: either `column` or `row`.
   - `style` (optional) An {Object} with styles to apply to the flexbox.
  ###
  @propTypes:
    direction: React.PropTypes.string
    style: React.PropTypes.object

  render: ->
    style = _.extend (@props.style || {}),
      'flexDirection': @props.direction,
      'position':'relative'
      'display': 'flex'
      'height':'100%'

    otherProps = _.omit(@props, _.keys(@constructor.propTypes))

    <div style={style} {...otherProps}>
      {@props.children}
    </div>


module.exports = Flexbox