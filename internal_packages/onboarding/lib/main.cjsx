ContainerView = require './container-view'
{WorkspaceStore, ComponentRegistry} = require 'nylas-exports'

module.exports =
  item: null

  activate: (@state) ->
    WorkspaceStore.defineSheet 'Main', {root: true},
      list: ['Center']
    ComponentRegistry.register ContainerView,
      location: WorkspaceStore.Location.Center
