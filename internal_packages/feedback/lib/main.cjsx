{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'
FeedbackButton = require './feedback-button'
protocol = require('remote').require('protocol')

module.exports =
  activate: (@state) ->
    ComponentRegistry.register FeedbackButton,
      location: WorkspaceStore.Sheet.Global.Footer

  serialize: ->

  deactivate: ->
    ComponentRegistry.unregister(FeedbackButton)
