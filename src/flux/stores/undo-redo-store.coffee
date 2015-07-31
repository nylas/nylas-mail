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
      @trigger() unless task._isReverting

  undo: =>
    topTask = @_undo.pop()
    return unless topTask
    @trigger()
    Actions.queueTask(topTask.createUndoTask())
    @_redo.push(topTask.createIdenticalTask())

  redo: =>
    redoTask = @_redo.pop()
    return unless redoTask
    Actions.queueTask(redoTask)

  getMostRecentTask: =>
    for idx in [@_undo.length-1...-1]
      return @_undo[idx] unless @_undo[idx]._isReverting

  print: ->
    console.log("Undo Stack")
    console.log(@_undo)
    console.log("Redo Stack")
    console.log(@_redo)

module.exports = new UndoRedoStore()
