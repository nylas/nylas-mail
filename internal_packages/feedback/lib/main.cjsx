{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'
FeedbackButton = require './feedback-button'
FeedbackActions = require './feedback-actions'
protocol = require('remote').require('protocol')

module.exports =
  activate: (@state) ->
    ComponentRegistry.register FeedbackButton,
      location: WorkspaceStore.Sheet.Global.Footer

    protocol.registerStringProtocol 'nylas-feedback-available', (request, callback) =>
      FeedbackActions.feedbackAvailable()
      callback('ok')

  serialize: ->

  deactivate: ->
    ComponentRegistry.unregister(FeedbackButton)
    protocol.unregisterProtocol('nylas-feedback-available')
