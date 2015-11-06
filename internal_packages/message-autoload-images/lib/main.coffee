{ComponentRegistry,
 MessageStore,
 WorkspaceStore} = require 'nylas-exports'

AutoloadImagesExtension = require './autoload-images-extension'
AutoloadImagesHeader = require './autoload-images-header'

module.exports =
  item: null # The DOM item the main React component renders into

  activate: (@state={}) ->
    # Register Message List Actions we provide globally
    MessageStore.registerExtension(AutoloadImagesExtension)
    ComponentRegistry.register AutoloadImagesHeader,
      role: 'message:BodyHeader'

  deactivate: ->
    MessageStore.unregisterExtension(AutoloadImagesExtension)
    ComponentRegistry.unregister(AutoloadImagesHeader)

  serialize: -> @state
