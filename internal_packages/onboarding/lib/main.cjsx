PageRouter = require "./page-router"
{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'

module.exports =
  item: null

  activate: (@state) ->
    # This package does nothing in other windows
    return unless atom.getWindowType() is 'onboarding'

    WorkspaceStore.defineSheet 'Main', {root: true},
      list: ['Center']

    ComponentRegistry.register PageRouter,
      location: WorkspaceStore.Location.Center
