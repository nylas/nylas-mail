{ComponentRegistry, WorkspaceStore} = require 'nylas-exports'

module.exports =
  activate: (@state={}) ->
    UndoRedoComponent = require "./undo-redo-component"

    ComponentRegistry.register UndoRedoComponent,
      location: WorkspaceStore.Location.ThreadList

  deactivate: ->
    ComponentRegistry.unregister UndoRedoComponent

  serialize: -> @state