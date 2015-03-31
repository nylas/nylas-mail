_ = require 'underscore-plus'
moment = require 'moment-timezone'
React = require 'react'
{Utils} = require 'inbox-exports'

module.exports =
MessageTimestamp = React.createClass
  displayName: 'MessageTimestamp'
  propTypes:
    date: React.PropTypes.object.isRequired,
    className: React.PropTypes.string,
    isDetailed: React.PropTypes.bool
    onClick: React.PropTypes.func

  shouldComponentUpdate: (nextProps, nextState) ->
    +nextProps.date isnt +@props.date or nextProps.isDetailed isnt @props.isDetailed

  render: ->
    <div className={@props.className}
         onClick={@props.onClick}>{@_formattedDate()}</div>

  _formattedDate: ->
    moment.tz(@props.date, Utils.timeZone).format(@_timeFormat())

  _timeFormat: ->
    if @props.isDetailed
      return "DD / MM / YYYY h:mm a z"
    else
      today = moment(@_today())
      dayOfEra = today.dayOfYear() + today.year() * 365
      msgDate = moment(@props.date)
      msgDayOfEra = msgDate.dayOfYear() + msgDate.year() * 365
      diff = dayOfEra - msgDayOfEra
      if diff < 1
        return "h:mm a"
      if diff < 4
        return "MMM D, h:mm a"
      else if diff > 1 and diff <= 365
        return "MMM D"
      else
        return "MMM D YYYY"

  # Stubbable for testing. Returns a `moment`
  _today: -> moment.tz(Utils.timeZone)


