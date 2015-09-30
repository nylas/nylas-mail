_ = require 'underscore'
Task = require './task'
Thread = require '../models/thread'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
AccountStore = require '../stores/account-store'
{APIError} = require '../errors'

# MapLimit is a small helper method that implements a promise version of
# Async.mapLimit. It runs the provided fn on each item in the `input` array,
# but only runs `numberInParallel` copies of `fn` at a time, resolving
# with an output array, or rejecting with an error if any execution of
# `fn` returns an error.
mapLimit = (input, numberInParallel, fn) ->
  new Promise (resolve, reject) ->
    idx = 0
    inflight = 0
    output = []
    outputError = null

    startNext = ->
      startIdx = idx
      idx += 1
      inflight += 1
      fn(input[startIdx])
      .then (result) =>
        output[startIdx] = result
        return if outputError

        inflight -= 1
        if idx < input.length
          startNext()
        else if inflight is 0
          resolve(output)

      .catch (err) =>
        outputError = err
        reject(outputError)

    numberInParallel = Math.min(numberInParallel, input.length)
    startNext() for n in [0...numberInParallel]

# The ChangeMailTask is a base class for all tasks that modify sets of threads or
# messages. Subclasses implement `_changesToModel` and `_requestBodyForModel` to
# define the specific transforms they provide, and override `performLocal` to
# perform additional consistency checks.
#
# ChangeMailTask aims to be fast and efficient. It does not write changes to the
# database or make API requests for models that are unmodified by `_changesToModel`
#
# ChangeMailTask stores the previous values of all models it changes into @_restoreValues
# and handles undo/redo. When undoing, it restores previous values and calls
# `_requestBodyForModel` to make undo API requests. It does not call `_changesToModel`.
##
class ChangeMailTask extends Task

  constructor: ({@threads, thread, @messages, message} = {}) ->
    @threads ?= []
    @threads.push(thread) if thread
    @messages ?= []
    @messages.push(message) if message
    super

  # Functions for subclasses

  # Override this method and return an object with key-value pairs representing
  # changed values. For example, if your task sets unread: false, return
  # {unread: false}.
  #
  _changesToModel: (model) ->
    throw new Error("You must override this method.")

  # Override this method and return an object that will be the request body
  # used for saving changes to `model`.
  #
  _requestBodyForModel: (model) ->
    throw new Error("You must override this method.")

  # Generally, you cannot provide both messages and threads at the same time. However,
  # ChangeMailTask runs for provided threads first and then messages. Override
  # and return true, and you will receive `_changesToModel` for messages in
  # changed threads, and any changes you make will be written to the database
  # and undone during undo.
  #
  # Note that API requests are only made for threads if threads are present.
  #
  _processesNestedMessages: ->
    false

  # Perform Local

  # Subclasses should override `performLocal` and call super once they've
  # prepared the data they need and verified that requirements are met.
  #
  # Note: Currently, *ALL* subclasses must use `DatabaseStore.modelify`
  # to convert `threads` and `messages` from models or ids to models.
  #
  performLocal: ->
    if @_isUndoTask and not @_restoreValues
      return Promise.reject(new Error("ChangeMailTask: No _restoreValues provided for undo task."))

    # Lock the models with the optimistic change tracker so they aren't reverted
    # while the user is seeing our optimistic changes.
    @_lockAll() unless @_isReverting

    @_performLocalThreads().then =>
      return @_performLocalMessages()

  _performLocalThreads: ->
    changed = @_applyChanges(@threads)
    changedIds = _.pluck(changed, 'id')

    DatabaseStore.persistModels(changed).then =>
      if @_processesNestedMessages()
        DatabaseStore.findAll(Message).where(Message.attributes.threadId.in(changedIds)).then (messages) =>
          @messages = [].concat(messages, @messages)
          Promise.resolve()
      else
        Promise.resolve()

  _performLocalMessages: ->
    changed = @_applyChanges(@messages)
    DatabaseStore.persistModels(changed)

  _applyChanges: (modelArray) ->
    changed = []

    if @_shouldChangeBackwards()
      for model, idx in modelArray
        if @_restoreValues[model.id]
          model = _.extend(model.clone(), @_restoreValues[model.id])
          modelArray[idx] = model
          changed.push(model)
    else
      @_restoreValues ?= {}
      for model, idx in modelArray
        fieldsNew = @_changesToModel(model)
        fieldsCurrent = _.pick(model, Object.keys(fieldsNew))
        if not _.isEqual(fieldsCurrent, fieldsNew)
          @_restoreValues[model.id] = fieldsCurrent
          model = _.extend(model.clone(), fieldsNew)
          modelArray[idx] = model
          changed.push(model)

    changed

  _shouldChangeBackwards: ->
    @_isReverting or @_isUndoTask

  # Perform Remote

  performRemote: ->
    @performRequests(@objectClass(), @objectArray()).then =>
      @_ensureLocksRemoved()
      return Promise.resolve(Task.Status.Finished)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        @_isReverting = true
        @performLocal().then =>
          @_ensureLocksRemoved()
          return Promise.resolve(Task.Status.Finished)
      else
        return Promise.resolve(Task.Status.Retry)

  performRequests: (klass, models) ->
    mapLimit models, 5, (model) =>
      # Don't bother making a web request if performLocal didn't modify this model
      return Promise.resolve() unless @_restoreValues[model.id]

      if klass is Thread
        endpoint = 'threads'
      else
        endpoint = 'messages'

      NylasAPI.makeRequest
        path: "/#{endpoint}/#{model.id}"
        accountId: model.accountId
        method: 'PUT'
        body: @_requestBodyForModel(model)
        returnsModel: true
        beforeProcessing: (body) =>
          @_removeLock(model)
          body
      .catch (err) =>
        if err instanceof APIError and err.statusCode is 404
          return Promise.resolve()
        Promise.reject(err)

  # Task lifecycle

  canBeUndone: -> true

  isUndo: -> @_isUndoTask is true

  createUndoTask: ->
    if @_isUndoTask
      throw new Error("ChangeMailTask::createUndoTask Cannot create an undo task from an undo task.")
    if not @_restoreValues
      throw new Error("ChangeMailTask::createUndoTask Cannot undo a task which has not finished performLocal yet.")

    task = @createIdenticalTask()
    task._restoreValues = @_restoreValues
    task._isUndoTask = true
    task

  createIdenticalTask: ->
    task = new @constructor(@)
    # Never give the undo task the Model objects - make it look them up!
    # This ensures that they never revert other fields
    toIds = (arr) -> _.map arr, (v) -> if _.isString(v) then v else v.id
    task.threads = toIds(@threads)
    task.messages = if @threads.length > 0 then [] else toIds(@messages)
    task

  objectIds: ->
    [].concat(@threads, @messages).map (i) ->
      if _.isString(i) then i else i.id

  objectClass: ->
    if @threads and @threads.length
      return Thread
    else
      return Message

  objectArray: ->
    if @threads and @threads.length
      return @threads
    else
      return @messages

  numberOfImpactedItems: ->
    @objectArray().length

  # To ensure that complex offline actions are synced correctly, label/folder additions
  # and removals need to be applied in order. (For example, star many threads,
  # and then unstar one.)
  shouldWaitForTask: (other) ->
    # Only wait on other tasks that are older and also involve the same threads
    return unless other instanceof ChangeMailTask
    otherOlder = other.creationDate < @creationDate
    otherSameObjs = _.intersection(other.objectIds(), @objectIds()).length > 0
    return otherOlder and otherSameObjs

  # Helpers used in subclasses

  _lockAll: ->
    klass = @objectClass()
    @_locked ?= {}
    for item in @objectArray()
      @_locked[item.id] ?= 0
      @_locked[item.id] += 1
      NylasAPI.incrementOptimisticChangeCount(klass, item.id)

  _removeLock: (item) ->
    klass = @objectClass()
    NylasAPI.decrementOptimisticChangeCount(klass, item.id)
    @_locked[item.id] -= 1

  _ensureLocksRemoved: ->
    klass = @objectClass()
    return unless @_locked
    for id, count of @_locked
      while count > 0
        NylasAPI.decrementOptimisticChangeCount(klass, id)
        count -= 1
    @_locked = null

module.exports = ChangeMailTask
