{ComponentRegistry} = require 'nylas-exports'
Participants = require './Participants'

module.exports =
  activate: (state) ->
    ComponentRegistry.register Participants,
      role: 'Participants'
