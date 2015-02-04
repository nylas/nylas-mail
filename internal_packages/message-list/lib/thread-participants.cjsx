_ = require 'underscore-plus'
React = require "react"

module.exports =
ThreadParticipants = React.createClass
  displayName: 'ThreadParticipants'
  
  render: ->
    <div className="participants thread-participants">
      {@_formattedParticipants()}
    </div>

  _formattedParticipants: ->
    contacts = @props.thread_participants ? []
    _.map(contacts, (c) -> c.displayName()).join(", ")
