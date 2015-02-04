{ComponentRegistry} = require 'inbox-exports'
InboxParticipants = require './InboxParticipants.cjsx'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'Participants'
      view: InboxParticipants
