moment = require 'moment'
React = require 'react'

module.exports =
MessageTimestamp = React.createClass
  displayName: 'MessageTimestamp'
  propTypes:
    date: React.PropTypes.object.isRequired,
    className: React.PropTypes.string,

  render: ->
    <div className={@props.className}>{moment(@props.date).format(@_timeFormat())}</div>

  _timeFormat: ->
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
  _today: -> moment()


