{ComponentRegistry} = require 'inbox-exports'

module.exports =
  activate: (@state={}) ->
    AttachmentComponent = require "./attachment-component"

    ComponentRegistry.register AttachmentComponent,
      role: 'Attachment'

  deactivate: ->
    ComponentRegistry.unregister AttachmentComponent
    
  serialize: -> @state
