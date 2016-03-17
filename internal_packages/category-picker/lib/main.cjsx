CategoryPicker = require "./category-picker"

{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register CategoryPicker,
      role: 'ThreadActionsToolbarButton'

  deactivate: ->
    ComponentRegistry.unregister(CategoryPicker)
