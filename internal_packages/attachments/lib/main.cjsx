{ComponentRegistry} = require 'nylas-exports'

AttachmentComponent = require "./attachment-component"
ImageAttachmentComponent = require "./image-attachment-component"

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register AttachmentComponent,
      role: 'Attachment'

    ComponentRegistry.register ImageAttachmentComponent,
      role: 'Attachment:Image'

  deactivate: ->
    ComponentRegistry.unregister(AttachmentComponent)
    ComponentRegistry.unregister(ImageAttachmentComponent)

  serialize: -> @state
