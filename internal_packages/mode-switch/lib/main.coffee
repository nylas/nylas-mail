{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'
ModeToggle = require './mode-toggle'

# NOTE: this is a hack to allow ComponentRegistry
# to register the same component multiple times in
# different areas. if we do this more than once, let's
# dry this out.
class ModeToggleList extends ModeToggle
  @displayName: 'ModeToggleList'

module.exports =
  activate: (state) ->
    ComponentRegistry.register ModeToggleList,
      location: WorkspaceStore.Sheet.Thread.Toolbar.Right
      modes: ['list']

    ComponentRegistry.register ModeToggle,
      location: WorkspaceStore.Sheet.Threads.Toolbar.Right
      modes: ['split']
