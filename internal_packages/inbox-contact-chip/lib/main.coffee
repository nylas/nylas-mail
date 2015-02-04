{ComponentRegistry} = require 'inbox-exports'
ContactChip = require './ContactChip.cjsx'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'ParticipantChip'
      view: ContactChip
