React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
DeveloperBar = require './developer-bar'

module.exports =
  item: null

  activate: (@state={}) ->
    ComponentRegistry.register DeveloperBar,
      location: WorkspaceStore.Sheet.Global.Footer

  deactivate: ->
    ComponentRegistry.unregister DeveloperBar
