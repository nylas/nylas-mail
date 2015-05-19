React = require "react"
_ = require "underscore"
ContactChip = require './ContactChip'

{NamespaceStore} = require "nylas-exports"

# Parameters
# clickable (optional) - is this currently clickable?
# thread (optional) - thread context for sorting
#  passed into the ParticipantChip
#  - 'primary'
#  - 'list'

class Participants extends React.Component
  @displayName: "Participants"

  @containerRequired: false

  render: =>
    chips = @getParticipants().map (p) =>
      <ContactChip key={p.nameEmail()} clickable={@props.clickable} participant={p} />

    <div displayName="div.participants" className="participants">
      {chips}
    </div>

  getParticipants: =>
    myEmail = NamespaceStore.current().emailAddress
    list = @props.participants

    # Remove 'Me' if there is more than one participant
    if list.length > 1
      list = _.reject list, (p) -> p.email is myEmail

    list.forEach (p) ->
      p.id = p.name+p.email

    list

  shouldComponentUpdate: (newProps, newState) =>
    !_.isEqual(newProps.participants, @props.participants)


module.exports = Participants
