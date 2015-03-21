{ComponentRegistry} = require 'inbox-exports'
ContactChip = require './ContactChip'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'ParticipantChip'
      view: ContactChip
