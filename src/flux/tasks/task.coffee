_ = require 'underscore'
{generateTempId} = require '../models/utils'
Actions = require '../actions'
{APIError,
 OfflineError,
 TimeoutError} = require '../errors'

TaskStatus =
  Finished: 'finished'
  Retry: 'retry'

# Public: Tasks represent individual changes to the datastore that
# alter the local cache and need to be synced back to the server.
#
# To create a new task, subclass Task and implement the following methods:
#
# - performLocal:
#   Return a {Promise} that does work immediately. Must resolve or the task
#   will be thrown out. Generally, you should optimistically update
#   the local cache here.
#
# - performRemote:
#   Do work that requires dependencies to have resolved and may need to be
#   tried multiple times to succeed in case of network issues.
#
#   performRemote must return a {Promise}, and it should always resolve with
#   Task.Status.Finished or Task.Status.Retry. Rejections are considered
#   exception cases and are logged to our server.
#
#   Returning Task.Status.Retry will cause the TaskQueue to leave your task
#   on the queue and run it again later. You should only return Task.Status.Retry
#   if your task encountered a transient error (for example, a `0` but not a `400`).
#
# - shouldWaitForTask:
#   Tasks may be arbitrarily dependent on other tasks. To ensure that
#   performRemote is called at the right time, subclasses should implement
#   `shouldWaitForTask(other)`. For example, the `SendDraft` task is dependent
#   on the draft's files' `UploadFile` tasks completing.
#
# Tasks may also implement shouldDequeueOtherTask(other). Returning true
# will cause the other event to be removed from the queue. This is useful in
# offline mode especially, when the user might Save,Save,Save,Save,Send.
# Each newly queued Save can cancel the (unstarted) save task in the queue.
#
# Tasks that need to support undo/redo should implement `canBeUndone`, `isUndo`,
# `createUndoTask`, and `createIdenticalTask`.
#
class Task

  @Status: TaskStatus

  constructor: ->
    @_rememberedToCallSuper = true
    @_performLocalCompletePromise = new Promise (resolve, reject) =>
      # This is called by the `TaskQueue` immeidately after `performLocal`
      # has finished and the task has been added to the Queue.
      @performLocalComplete = resolve

    @id = generateTempId()
    @creationDate = new Date()
    @queueState =
      isProcessing: false
      localError: null
      localComplete: false
      remoteError: null
      remoteAttempts: 0
      remoteComplete: false
    @

  runLocal: ->
    if not @_rememberedToCallSuper
      throw new Error("Your must call `super` from your Task's constructors")

    if @queueState.localComplete
      return Promise.resolve()
    else
      @performLocal()
      .then =>
        @queueState.localComplete = true
        @queueState.localError = null
        return Promise.resolve()
      .catch (err) =>
        @queueState.localError = err
        return Promise.reject(err)

  runRemote: ->
    if @queueState.localComplete is false
      throw new Error("runRemote called before performLocal complete, this is an assertion failure.")

    if @queueState.remoteComplete
      return Promise.resolve(Task.Status.Finished)

    @performRemote()
    .catch (err) =>
      @queueState.remoteAttempts += 1
      @queueState.remoteError = err
    .then (status) =>
      if not (status in _.values(Task.Status))
        throw new Error("performRemote returned #{status}, which is not a Task.Status")
      @queueState.remoteAttempts += 1
      @queueState.remoteComplete = status is Task.Status.Finished
      @queueState.remoteError = null
      return Promise.resolve(status)


  ## Everything beneath here may be overridden in subclasses ##

  # performLocal is called once when the task is queued. You must return
  # a promise. If you resolve, the task is queued and performRemote will
  # be called. If you reject, the task will not be queued.
  #
  performLocal: ->
    Promise.resolve()

  performRemote: ->
    Promise.resolve(Task.Status.Finished)

  waitForPerformLocal: ->
    if not atom.isMainWindow()
      throw new Error("waitForPerformLocal is only supported in the main window. In
             secondary windows, tasks are serialized and sent to the main
             window, and cannot be observed.")
    if not @_performLocalCompletePromise
      throw new Error("This #{@constructor.name} Task did not call `super` in it's constructor! You must call `super`")
    @_performLocalCompletePromise

  cancel: ->
    # We ignore requests to cancel and carry on. Subclasses that want to support
    # cancellation or dequeue requests while running should implement cancel.

  canBeUndone: -> false

  isUndo: -> false

  createUndoTask: -> throw new Error("Unimplemented")

  createIdenticalTask: ->
    json = @toJSON()
    delete json['queueState']
    (new @.constructor).fromJSON(json)

  shouldDequeueOtherTask: (other) -> false

  shouldWaitForTask: (other) -> false

  toJSON: ->
    json = _.clone(@)
    json['object'] = @constructor.name
    json

  fromJSON: (json) ->
    for key,val of json
      @[key] = val
    @

module.exports = Task
