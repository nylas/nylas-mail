CategoryPicker = require "./category-picker"

{ComponentRegistry,
 WorkspaceStore} = require 'nylas-exports'

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register CategoryPicker,
      roles: ['thread:BulkAction', 'message:Toolbar']

  deactivate: ->
    ComponentRegistry.unregister(CategoryPicker)
