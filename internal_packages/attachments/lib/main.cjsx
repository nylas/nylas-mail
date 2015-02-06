{ComponentRegistry} = require 'inbox-exports'

module.exports =
  activate: (@state={}) ->
    console.log "REGISTERING MESSAGE ATTACHMENT"
    MessageAttachment = require "./message-attachment.cjsx"

    ComponentRegistry.register
      name: 'MessageAttachment'
      view: MessageAttachment
      role: 'Attachment'

  deactivate: ->
    ComponentRegistry.unregister "MessageAttachment"

  serialize: -> @state
