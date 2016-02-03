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

    @listenTo(Actions.queueTask, @_onQueue)
    @listenTo(Actions.queueTasks, @_onQueue)

    NylasEnv.commands.add('body', {'core:undo': @undo })
    NylasEnv.commands.add('body', {'core:redo': @redo })

  _onQueue: (tasks) =>
    tasks = [tasks] unless tasks instanceof Array
    undoable = _.every tasks, (t) -> t.canBeUndone()

    if undoable
      @_redo = []
      @_undo.push(tasks)
      @trigger()

  undo: =>
    topTasks = @_undo.pop()
    return unless topTasks
    @trigger()

    for task in topTasks
      Actions.undoTaskId(task.id)

    redoTasks = topTasks.map (t) -> t.createIdenticalTask()
    @_redo.push(redoTasks)

  redo: =>
    redoTasks = @_redo.pop()
    return unless redoTasks
    Actions.queueTasks(redoTasks)

  getMostRecent: =>
    for idx in [@_undo.length-1...-1]
      allReverting = _.every @_undo[idx], (t) -> t._isReverting
      return @_undo[idx] unless allReverting

  print: ->
    console.log("Undo Stack")
    console.log(@_undo)
    console.log("Redo Stack")
    console.log(@_redo)

module.exports = new UndoRedoStore()
