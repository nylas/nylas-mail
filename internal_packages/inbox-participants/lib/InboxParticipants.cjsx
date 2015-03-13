{ComponentRegistry, NamespaceStore} = require "inbox-exports"
React = require "react"
_ = require "underscore-plus"

DefaultChip = React.createClass
  render: ->
    display = @props.participant.name? and @props.participant.name or @props.participant.email
    <span className="default-participant-chip">{display}</span>

# Parameters
# clickable (optional) - is this currently clickable?
# thread (optional) - thread context for sorting
# context (optional) - additional information for determining appearance,
#  passed into the ParticipantChip
#  - 'primary'
#  - 'list'

module.exports = React.createClass
  mixins: [ComponentRegistry.Mixin]
  components: ["ParticipantChip"]

  render: ->
    ParticipantChip = @state.ParticipantChip ? DefaultChip
    chips = @getParticipants().map (p) =>
      <ParticipantChip key={p.id}
        displayName="ParticipantChip"
        clickable={@props.clickable}
        context={@props.context}
        participant={p} />

    <div displayName="div.participants" className="participants">
      {chips}
    </div>

  getParticipants: ->
    myEmail = NamespaceStore.current().emailAddress
    list = @props.participants

    # Remove 'Me' if there is more than one participant
    if list.length > 1
      list = _.reject list, (p) -> p.email is myEmail

    list.forEach (p) ->
      p.id = p.name+p.email

    list

  shouldComponentUpdate: (newProps, newState) ->
    !_.isEqual(newProps.participants, @props.participants)
