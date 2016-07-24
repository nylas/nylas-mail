_ = require 'underscore'
moment = require 'moment-timezone'
React = require 'react'
{DateUtils, Utils} = require 'nylas-exports'

class MessageTimestamp extends React.Component
  @displayName: 'MessageTimestamp'
  @propTypes:
    date: React.PropTypes.object.isRequired,
    className: React.PropTypes.string,
    isDetailed: React.PropTypes.bool
    onClick: React.PropTypes.func

  shouldComponentUpdate: (nextProps, nextState) =>
    +nextProps.date isnt +@props.date or nextProps.isDetailed isnt @props.isDetailed

  render: =>
    if @props.isDetailed
      formattedDate = DateUtils.mediumTimeString(@props.date)
    else
      fromattedDate = DateUtils.shortTimeString(@props.date)
    <div className={@props.className}
         title={DateUtils.fullTimeString(@props.date)}
         onClick={@props.onClick}>{formattedDate}</div>

  # Stubbable for testing. Returns a `moment`
  _today: -> moment.tz(Utils.timeZone)

module.exports = MessageTimestamp
