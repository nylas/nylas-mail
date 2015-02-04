{ComponentRegistry, NamespaceStore} = require "inbox-exports"
React = require "react"
_ = require "underscore-plus"

SORT = false

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
    me = NamespaceStore.current().me()

    if SORT
      sorted = _.sortBy @props.participants, (p) -> p.displayName()
    else
      sorted = @props.participants

    # Pull 'me'
    user = _.findWhere sorted, me
    if self
      sorted = _.without sorted, user

    # Push 'me' if we just emptied the list
    if user? and sorted.length == 0
      sorted.push me
    # Unshift 'me' if context says we're the sender
    else if @_fromUserUnrepliedContext()
      sorted.unshift me
    # Unshift 'me' if context says we're the sender and it's a group thread
    else if @_fromUserGroupThreadContext()
      sorted.unshift me

    # Pull the sender to the front, if it's not 'me'
    if @_getSender()? and @_getSender().email != me.email
      # It's probably the same contact object but why risk the fuck up?
      sender = _.findWhere sorted, {email: @_getSender().email}
      sorted = _.without sorted, sender
      sorted.unshift sender

    sorted.forEach (p) ->
      p.id = p.name+p.email

    sorted

  shouldComponentUpdate: (newProps, newState) ->
    !_.isEqual(newProps.participants, @props.participants)

  # TODO - this'll require poking DatabaseStore
  # UPDATE: Please move these so they're injected via props from somewhere
  # that has the thread object. DON'T QUERY HERE! (@ben)
  _fromUserUnrepliedContext: ->
    false

  _fromUserGroupThreadContext: ->
    false

  _getSender: ->
    undefined
