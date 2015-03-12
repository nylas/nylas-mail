React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry} = require "inbox-exports"

module.exports =
Flexbox = React.createClass
  displayName: 'Flexbox'
  propTypes:
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
