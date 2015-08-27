React = require 'react'
{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
DeveloperBar = require './developer-bar'

module.exports =
  item: null

  activate: (@state={}) ->
    WorkspaceStore.defineSheet 'Main', {root: true},
      popout: ['Center']

    ComponentRegistry.register DeveloperBar,
      location: WorkspaceStore.Location.Center

  deactivate: ->
    ComponentRegistry.unregister DeveloperBar
