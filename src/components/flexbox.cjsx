React = require 'react'
_ = require 'underscore-plus'
{Actions,ComponentRegistry} = require "inbox-exports"

module.exports =
Flexbox = React.createClass
  displayName: 'Flexbox'
  propTypes:
    name: React.PropTypes.string
    direction: React.PropTypes.string
    style: React.PropTypes.object

  render: ->
    style = _.extend (@props.style || {}),
      'flexDirection': @props.direction,
      'position':'relative'
      'display': 'flex'
      'height':'100%'

    <div name={name} style={style}>
      {@props.children}
    </div>
