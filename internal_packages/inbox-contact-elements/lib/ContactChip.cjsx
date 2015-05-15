React = require "react"
{Actions} = require 'nylas-exports'
crypto = require "crypto"

class ContactChip extends React.Component
  @displayName: "ContactChip"

  render: =>
    className = "contact-chip"
    if @props.clickable
      className += " clickable"

    <span className={className} onClick={@_onClick}>
      <span className="contact-name">{@_getParticipantDisplay()}</span>
    </span>

  _onClick: =>
    return unless @props.clickable
    clipboard = require('clipboard')
    clipboard.writeText(@props.participant.email)
    Actions.postNotification({message: "Copied #{@props.participant.email} to clipboard", type: 'success'})

  _getParticipantDisplay: =>
    @props.participant.displayName()

  shouldComponentUpdate: (newProps, newState) =>
    (newProps.participant?.email != @props.participant?.email) ||
    (newProps.participant?.name  != @props.participant?.name)

  componentWillMount: =>
    email = @props.participant.email.toLowerCase()
    @md5 = crypto.createHash('md5').update(email).digest('hex')

    nameMD5 = crypto.createHash('md5').update(email + @props.participant.name).digest('hex')
    n = Math.floor(parseInt(nameMD5.slice(0, 2), 16) * 360/256)
    @bg = "hsl(#{n}, 50%, 50%)"


module.exports = ContactChip
