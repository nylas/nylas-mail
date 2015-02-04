React = require 'react'
_ = require 'underscore-plus'

module.exports = ComposerParticipant = React.createClass
  render: ->
    <span className={!_.isEmpty(@props.participant.name) and "hasName" or ""}>
      <span className="name">{@props.participant.name}</span>
      <span className="email">{@props.participant.email}</span>
      <button className="remove" onClick={=> @props.onRemove(@props.participant)} ><i className="fa fa-remove"></i></button>
    </span>
