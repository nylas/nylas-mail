_ = require 'underscore'
Task = require './task'
Thread = require '../models/thread'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
NamespaceStore = require '../stores/namespace-store'
{APIError} = require '../errors'

class ChangeCategoryTask extends Task

  canBeUndone: -> true

  isUndo: -> @_isUndoTask is true

  # To ensure that complex offline actions are synced correctly, tag additions
  # and removals need to be applied in order. (For example, star many threads,
  # and then unstar one.)
  shouldWaitForTask: (other) ->
    # Only wait on other tasks that are older and also involve the same threads
    return unless other instanceof ChangeCategoryTask
    otherOlder = other.creationDate < @creationDate
    otherSameObjs = _.intersection(other.objectIds, @objectIds).length > 0
    return otherOlder and otherSameObjs

  verifyArgs: ->
    if not @objectIds or not @objectIds instanceof Array
      return Promise.reject(new Error("Attempt to call ChangeCategoryTask::performLocal without threads"))
    if @threadIds.length > 0 and @messageIds.length > 0
      return Promise.reject(new Error("You can only move `threadIds` xor `messageIds` but not both"))
    return null

  _endpoint: ->
    if @threadIds.length > 0 then return "threads"
    else if @messageIds.length > 0 then return "messages"

  performLocal: ({reverting} = {}) ->
    @_isReverting = reverting
    err = @verifyArgs()
    return err if err

    @collectCategories().then (categories) =>
      promises = @objectIds.map (objectId) =>
        if @threadIds.length > 0 then Klass = Thread
        else if @messageIds.length > 0 then Klass = Message
        DatabaseStore.find(Klass, objectId).then (object) =>
          # Mark that we are optimistically changing this model. This will prevent
          # inbound delta syncs from changing it back to it's old state. Only the
          # operation that changes `optimisticChangeCount` back to zero will
          # apply the server's version of the model to our cache.
          if reverting is true
            NylasAPI.decrementOptimisticChangeCount(Klass, object.id)
          else
            NylasAPI.incrementOptimisticChangeCount(Klass, object.id)

          if @threadIds.length > 0
            return @localUpdateThread(object, categories)
          else if @messageIds.length > 0
            return @localUpdateMessage(object, categories)

      return Promise.all(promises)

  performRemote: ->
    nsid = NamespaceStore.current()?.id
    promises = @objectIds.map (id) =>
      NylasAPI.makeRequest
        path: "/n/#{nsid}/#{@_endpoint()}/#{id}"
        method: 'PUT'
        body: @requestBody(id)
        returnsModel: true
        beforeProcessing: (body) ->
          NylasAPI.decrementOptimisticChangeCount(Thread, id)
          body

    Promise.all(promises)
    .then =>
      return Promise.resolve(Task.Status.Finished)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        return @rollbackLocal()
      else
        return Promise.resolve(Task.Status.Retry)

module.exports = ChangeCategoryTask
