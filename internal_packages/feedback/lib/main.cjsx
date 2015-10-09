{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'
FeedbackButton = require './feedback-button'
FeedbackActions = require './feedback-actions'
protocol = require('remote').require('protocol')

module.exports =
  activate: (@state) ->
    ComponentRegistry.register FeedbackButton,
      location: WorkspaceStore.Sheet.Global.Footer

    protocol.registerProtocol 'nylas-feedback-available', =>
      FeedbackActions.feedbackAvailable()

  serialize: ->

  deactivate: ->
    ComponentRegistry.unregister(FeedbackButton)
    protocol.unregisterProtocol('nylas-feedback-available')
