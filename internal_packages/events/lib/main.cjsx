# {ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
# EventComponent = require "./event-component"

module.exports =
  activate: (@state={}) ->
    # ComponentRegistry.register EventComponent,
    #   role: 'Event'

  deactivate: ->
    # ComponentRegistry.unregister(EventComponent)

  serialize: -> @state
