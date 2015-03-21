{ComponentRegistry} = require 'inbox-exports'
InboxParticipants = require './InboxParticipants'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'Participants'
      view: InboxParticipants
