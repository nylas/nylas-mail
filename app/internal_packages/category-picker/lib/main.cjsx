MovePicker = require "./move-picker"
LabelPicker = require "./label-picker"

{ComponentRegistry,
 WorkspaceStore} = require 'mailspring-exports'

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register MovePicker,
      role: 'ThreadActionsToolbarButton'
    ComponentRegistry.register LabelPicker,
      role: 'ThreadActionsToolbarButton'

  deactivate: ->
    ComponentRegistry.unregister(MovePicker)
    ComponentRegistry.unregister(LabelPicker)
