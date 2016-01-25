{ExtensionRegistry} = require 'nylas-exports'
SendAndArchiveExtension = require './send-and-archive-extension'

module.exports =
  activate: (@state={}) ->
    ExtensionRegistry.Composer.register(SendAndArchiveExtension)

  deactivate: ->
    ExtensionRegistry.Composer.unregister(SendAndArchiveExtension)

  serialize: -> @state
