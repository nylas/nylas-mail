{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
ModeToggle = require './mode-toggle'

module.exports =
  activate: (state) ->
    ComponentRegistry.register ModeToggle,
      location: WorkspaceStore.Sheet.Global.Toolbar.Right
