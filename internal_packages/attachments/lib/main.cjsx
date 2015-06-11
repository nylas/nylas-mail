{ComponentRegistry} = require 'nylas-exports'

module.exports =
  activate: (@state={}) ->
    AttachmentComponent = require "./attachment-component"
    ImageAttachmentComponent = require "./image-attachment-component"

    ComponentRegistry.register AttachmentComponent,
      role: 'Attachment'

    ComponentRegistry.register ImageAttachmentComponent,
      role: 'Attachment:Image'

  deactivate: ->
    ComponentRegistry.unregister AttachmentComponent
    ComponentRegistry.unregister ImageAttachmentComponent

  serialize: -> @state
