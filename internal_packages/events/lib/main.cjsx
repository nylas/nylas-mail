{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'

module.exports =
  activate: (@state={}) ->
    EventComponent = require "./event-component"

    ComponentRegistry.register EventComponent,
      role: 'Event'

  deactivate: ->
    ComponentRegistry.unregister EventComponent

  serialize: -> @state