Task = require './task'
{APIError} = require '../errors'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
NamespaceStore = require '../stores/namespace-store'
Actions = require '../actions'
Tag = require '../models/tag'
Thread = require '../models/thread'
_ = require 'underscore'
async = require 'async'

module.exports =
class AddRemoveTagsTask extends Task

  constructor: (@threadsOrIds, @tagIdsToAdd = [], @tagIdsToRemove = []) ->
    # For backwards compatibility, allow someone to make the task with a single thread
    # object or it's ID
    if @threadsOrIds instanceof Thread or _.isString(@threadsOrIds)
      @threadsOrIds = [@threadsOrIds]
    super

  label: ->
    "Applying tags..."

  threadIds: ->
    @threadsOrIds.map (t) -> if t instanceof Thread then t.id else t

  # Undo & Redo support

  canBeUndone: ->
    true

  isUndo: ->
    @_isUndoTask is true

  createUndoTask: ->
    task = new AddRemoveTagsTask(@threadIds(), @tagIdsToRemove, @tagIdsToAdd)
    task._isUndoTask = true
    task

  # Core Behavior

  # To ensure that complex offline actions are synced correctly, tag additions
  # and removals need to be applied in order. (For example, star many threads,
  # and then unstar one.)
  shouldWaitForTask: (other) ->
    # Only wait on other tasks that are older and also involve the same threads
    return unless other instanceof AddRemoveTagsTask
    otherOlder = other.creationDate < @creationDate
    otherSameThreads = _.intersection(other.threadIds(), @threadIds()).length > 0
    return otherOlder and otherSameThreads

  performLocal: ({reverting} = {}) ->
    if not @threadsOrIds or not @threadsOrIds instanceof Array
      return Promise.reject(new Error("Attempt to call AddRemoveTagsTask.performLocal without threads"))

    # collect all of the tag models we need.
    needed = {}
    for id in @tagIdsToAdd
      if id in ['archive', 'unread', 'inbox', 'unseen']
        needed["tag-#{id}"] = new Tag(id: id, name: id)
      else
        needed["tag-#{id}"] = DatabaseStore.find(Tag, id)

    Promise.props(needed).then (objs) =>
      promises = @threadsOrIds.map (item) =>
        getThread = Promise.resolve(item)
        if _.isString(item)
          getThread = DatabaseStore.find(Thread, item)

        getThread.then (thread) =>
          # Always apply our changes to a new copy of the thread.
          # In some scenarios it may actually be frozen
          thread = new Thread(thread)

          # Mark that we are optimistically changing this model. This will prevent
          # inbound delta syncs from changing it back to it's old state. Only the
          # operation that changes `optimisticChangeCount` back to zero will
          # apply the server's version of the model to our cache.
          if reverting is true
            NylasAPI.decrementOptimisticChangeCount(Thread, thread.id)
          else
            NylasAPI.incrementOptimisticChangeCount(Thread, thread.id)

          # filter the tags array to exclude tags we're removing and tags we're adding.
          # Removing before adding is a quick way to make sure they're only in the set
          # once. (super important)
          thread.tags = _.filter thread.tags, (tag) =>
            @tagIdsToRemove.indexOf(tag.id) is -1 and @tagIdsToAdd.indexOf(tag.id) is -1

          # add tags in the add list
          for id in @tagIdsToAdd
            tag = objs["tag-#{id}"]
            thread.tags.push(tag) if tag

          return DatabaseStore.persistModel(thread)

      Promise.all(promises)

  performRemote: ->
    nsid = NamespaceStore.current()?.id
    promises = @threadIds().map (id) =>
      NylasAPI.makeRequest
        path: "/n/#{nsid}/threads/#{id}"
        method: 'PUT'
        body:
          add_tags: @tagIdsToAdd,
          remove_tags: @tagIdsToRemove
        returnsModel: true
        beforeProcessing: (body) ->
          NylasAPI.decrementOptimisticChangeCount(Thread, id)
          body

    Promise.all(promises)
    .then =>
      return Promise.resolve(Task.Status.Finished)

    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        # Run performLocal backwards to undo the tag changes
        [@tagIdsToAdd, @tagIdsToRemove] = [@tagIdsToRemove, @tagIdsToAdd]
        @performLocal({reverting: true}).then =>
          return Promise.resolve(Task.Status.Finished)
      else
        return Promise.resolve(Task.Status.Retry)
