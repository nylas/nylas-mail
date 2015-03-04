_ = require 'underscore-plus'
React = require "react"

module.exports =
MessageParticipants = React.createClass
  displayName: 'MessageParticipants'

  render: ->
    <div className="participants message-participants">
      {@_formattedParticipants()}
    </div>

  _formattedParticipants: ->
    <span>
      <span className="participant-label from-label">From:</span>
      <span className="participant-name from-contact">{@_joinNames(@props.from)}</span>
      {if @_isToEveryone() then @_toEveryone() else @_toSome()}
    </span>

  _toEveryone: ->
    <span>
      <span className="participant-label to-label">&nbsp;>&nbsp;</span>
      <span className="participant-name to-everyone">Everyone</span>
    </span>

  _toSome: ->
    if @props.cc.length > 0
      cc_spans = <span>
        <span className="participant-label cc-label">CC:&nbsp;</span>
        <span className="participant-name cc-contact">{@_joinNames(@props.cc)}</span>
      </span>
    <span>
      <span className="participant-label to-label">&nbsp;>&nbsp;</span>
      <span className="participant-name to-contact">{@_joinNames(@props.to)}</span>
      {cc_spans}
    </span>

  _joinNames: (contacts=[]) ->
    _.map(contacts, (c) -> c.displayFirstName()).join(", ")

  _isToEveryone: ->
    mp = _.map(@props.message_participants, (c) -> c.email)
    tp = _.map(@props.thread_participants, (c) -> c.email)
    mp.length > 10 and _.difference(tp, mp).length is 0
