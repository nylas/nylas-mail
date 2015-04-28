{ComponentRegistry} = require 'inbox-exports'
ContactChip = require './ContactChip'
Participants = require './Participants'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'Participants'
      view: Participants

    ComponentRegistry.register
      name: 'ContactChip'
      view: ContactChip
