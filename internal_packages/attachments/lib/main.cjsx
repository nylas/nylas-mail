{ComponentRegistry} = require 'inbox-exports'

module.exports =
  activate: (@state={}) ->
    MessageAttachment = require "./message-attachment.cjsx"

    ComponentRegistry.register
      name: 'MessageAttachment'
      view: MessageAttachment
      role: 'Attachment'

  deactivate: ->
    ComponentRegistry.unregister "MessageAttachment"

  serialize: -> @state
