_ = require 'underscore'

{Listener, Publisher} = require '../modules/reflux-coffee'
CoffeeHelpers = require '../coffee-helpers'

Task = require "../tasks/task"
Actions = require '../actions'

class UndoRedoStore
  @include: CoffeeHelpers.includeModule

  @include Publisher
  @include Listener

  constructor: ->
    @_undo = []
    @_redo = []

    @listenTo(Actions.queueTask, @_onTaskQueued)

    atom.commands.add('body', {'core:undo': => @undo() })
    atom.commands.add('body', {'core:redo': => @redo() })

  _onTaskQueued: (task) =>
    if task.canBeUndone() and not task.isUndo()
      @_redo = []
      @_undo.push(task)

  undo: =>
    topTask = @_undo.pop()
    return unless topTask

    Actions.queueTask(topTask.createUndoTask())
    @_redo.push(topTask.createIdenticalTask())

  redo: =>
    redoTask = @_redo.pop()
    return unless redoTask
    Actions.queueTask(redoTask)

  print: ->
    console.log("Undo Stack")
    console.log(@_undo)
    console.log("Redo Stack")
    console.log(@_redo)

module.exports = new UndoRedoStore()
