{ComponentRegistry,
 ExtensionRegistry,
 WorkspaceStore} = require 'nylas-exports'

AutoloadImagesExtension = require './autoload-images-extension'
AutoloadImagesHeader = require './autoload-images-header'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    ExtensionRegistry.MessageView.register AutoloadImagesExtension
    ComponentRegistry.register AutoloadImagesHeader,
      role: 'message:BodyHeader'

  deactivate: ->
    ExtensionRegistry.MessageView.unregister AutoloadImagesExtension
    ComponentRegistry.unregister(AutoloadImagesHeader)

  serialize: -> @state
