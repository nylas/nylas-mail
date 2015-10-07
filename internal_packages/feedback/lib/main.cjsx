{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'

FeedbackButton = require './feedback-button'


path = require.resolve("electron-safe-ipc/host")
ipc = require('remote').require(path)


module.exports =
  activate: (@state) ->
    ComponentRegistry.register FeedbackButton,
      location: WorkspaceStore.Sheet.Global.Footer

  serialize: ->

  deactivate: ->
    ComponentRegistry.unregister(FeedbackButton)
