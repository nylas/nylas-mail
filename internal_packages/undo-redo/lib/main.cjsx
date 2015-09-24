{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'

UndoRedoComponent = require "./undo-redo-component"

module.exports =
  activate: (@state={}) ->
    ComponentRegistry.register UndoRedoComponent,
      location: WorkspaceStore.Location.ThreadList

  deactivate: ->
    ComponentRegistry.unregister(UndoRedoComponent)

  serialize: -> @state
