{ComponentRegistry} = require 'inbox-exports'
ResizableComponent = require './resizable-component.cjsx'

module.exports =
  activate: ->
    console.log "REGISTERING RESIZABLE COMPONENT"
    ComponentRegistry.register
      name: 'ResizableComponent'
      view: ResizableComponent

  deactivate: (state) ->
    ComponentRegistry.unregister 'ResizableComponent'

  serialize: ->
