{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
EventHeader = require "./event-header"

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register EventHeader,
      role: 'message:BodyHeader'

  deactivate: ->
    ComponentRegistry.unregister(EventHeader)

  serialize: -> @state
