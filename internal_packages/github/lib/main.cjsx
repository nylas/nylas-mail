{ComponentRegistry} = require 'nylas-exports'
ViewOnGithubButton = require "./view-on-github-button"

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register ViewOnGithubButton,
      roles: ['message:Toolbar']

  deactivate: ->
    ComponentRegistry.unregister(ViewOnGithubButton)

  serialize: -> @state
