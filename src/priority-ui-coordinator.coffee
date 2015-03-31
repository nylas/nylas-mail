{generateTempId} = require './flux/models/utils'

# A small object that keeps track of the current animation state of the
# application. You can use it to defer work until animations have finished.
# Integrated with our fork of TimeoutTransitionGroup
#
#  PriorityUICoordinator.settle.then ->
#   # Do something expensive
#
class PriorityUICoordinator
  constructor: ->
    @tasks = {}
    @settle = Promise.resolve()
    setInterval(( => @detectOrphanedTasks()), 1000)

  beginPriorityTask: ->
    if Object.keys(@tasks).length is 0
      @settle = new Promise (resolve, reject) =>
        @settlePromiseResolve = resolve

    id = generateTempId()
    @tasks[id] = Date.now()
    id

  endPriorityTask: (id) ->
    throw new Error("You must provide a task id to endPriorityTask") unless id
    delete @tasks[id]
    if Object.keys(@tasks).length is 0
      @settlePromiseResolve() if @settlePromiseResolve
      @settlePromiseResolve = null
 
  detectOrphanedTasks: ->
    now = Date.now()
    threshold = 15000 # milliseconds
    for id, timestamp of @tasks
      if now - timestamp > threshold
        console.log("PriorityUICoordinator detected oprhaned priority task lasting #{threshold}ms. Ending.")
        @endPriorityTask(id)

  busy: ->
    Object.keys(@tasks).length > 0

module.exports = new PriorityUICoordinator()