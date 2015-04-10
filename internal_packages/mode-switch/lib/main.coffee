{ComponentRegistry, WorkspaceStore} = require 'inbox-exports'
ModeToggle = require './mode-toggle'

module.exports =
  activate: (state) ->
    ComponentRegistry.register
      name: 'ModeToggle'
      view: ModeToggle
      location: WorkspaceStore.Sheet.Global.Toolbar.Right
