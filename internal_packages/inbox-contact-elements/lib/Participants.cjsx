React = require "react"
_ = require "underscore-plus"

{NamespaceStore} = require "inbox-exports"
{InjectedComponent} = require 'ui-components'

# Parameters
# clickable (optional) - is this currently clickable?
# thread (optional) - thread context for sorting
# context (optional) - additional information for determining appearance,
#  passed into the ParticipantChip
#  - 'primary'
#  - 'list'

module.exports = React.createClass
  render: ->
    chips = @getParticipants().map (p) =>
      <InjectedComponent name="ContactChip"
        key={p.id}
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
