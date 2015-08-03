_ = require 'underscore'
Task = require './task'
Label = require '../models/label'
Thread = require '../models/thread'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
ChangeCategoryTask = require './change-category-task'

# Public: Create a new task to apply labels to a message or thread.
#
# Takes an options array of the form:
#   - `labelsToAdd` An {Array} of {Label}s or {Label} ids to add
#   - `labelsToRemove` An {Array} of {Label}s or {Label} ids to remove
#   - `threadIds` Ether an arry of {Thread} ids…
#   - `messageIds` OR an arry of {Message} ids.
class ChangeLabelsTask extends ChangeCategoryTask

  constructor: ({@labelsToAdd, @labelsToRemove, @threadIds, @messageIds}={}) ->
    @threadIds ?= []; @messageIds ?= []
    @objectIds = @threadIds.concat(@messageIds)
    @_newLabels = {}
    super

  label: -> "Applying labels…"

  description: ->
    addingMessage = "Adding " + @labelsToAdd.length + " labels"
    removingMessage = "Removing " + @labelsToRemove.length + " labels"

    return addingMessage + " " + removingMessage

  collectCategories: ->
    labelOrIdPromiseMapper = (labelOrId) ->
      if labelOrId instanceof Label
        return Promise.resolve(labelOrId)
      else
        return DatabaseStore.find(Label, labelOrId)

    labelsToAdd = Promise.all @labelsToAdd.map(labelOrIdPromiseMapper)
    labelsToRemove = Promise.all @labelsToRemove.map(labelOrIdPromiseMapper)

    categories = Promise.props
      labelsToAdd: Promise.all(labelsToAdd ? [])
      labelsToRemove: Promise.all(labelsToRemove ? [])

    return categories

  # Called from super-class's `performRemote`
  rollbackLocal: ->
    [@labelsToAdd, @labelsToRemove] = [@labelsToRemove, @labelsToAdd]
    @performLocal({reverting: true}).then =>
      return Promise.resolve(Task.Status.Finished)

  requestBody: (id) ->
    labels: @_newLabels[id].map (l) -> l.id

  createUndoTask: ->
    labelsToAdd = @labelsToRemove
    labelsToRemove = @labelsToAdd
    args = {labelsToAdd, labelsToRemove, @threadIds, @messageIds}
    task = new ChangeLabelsTask(args)
    task._isUndoTask = true
    return task

  # Called from super-class's `performLocal`
  localUpdateThread: (thread, categories) ->
    newLabels = @_newLabelSet(thread, categories)
    @_newLabels[thread.id] = newLabels

    messageQuery = DatabaseStore.findAll(Message, threadId: thread.id)
    childSavePromise = messageQuery.then (messages) ->
      messagesToSave = []
      newIds = newLabels.map (l) -> l.id
      for message in messages
        existingIds = (message.labels ? []).map (l) -> l.id
        if _.isEqual(existingIds, newIds)
          continue
        else
          message.labels = newLabels
          messagesToSave.push(message)
      DatabaseStore.persistModels(messagesToSave)

    thread.labels = newLabels
    parentSavePromise = DatabaseStore.persistModel(thread)
    return Promise.all([parentSavePromise, childSavePromise])

  # Called from super-class's `performLocal`
  localUpdateMessage: (message, categories) ->
    message.labels = @_newLabelSet(message, categories)
    @_newLabels[message.id] = message.labels
    return DatabaseStore.persistModel(message)

  # Returns a new set of {Label} objects that incoprates the existing,
  # new, and removed labels.
  _newLabelSet: (object, {labelsToAdd, labelsToRemove}) ->
    contains = (list, val) -> val?.id? and (val.id in list.map((l) -> l.id))
    objLabels = object.labels ? []; labelsToAdd ?= []; labelsToRemove ?= []

    objLabels = objLabels.concat(labelsToAdd)

    objLabels = _.reject objLabels, (label) ->
      contains(labelsToRemove, label)

    return _.uniq(objLabels, false, (obj) -> obj.id)

  verifyArgs: ->
    @labelsToAdd ?= []
    @labelsToRemove ?= []
    if @labelsToAdd.length is 0 and @labelsToRemove.length is 0
      return Promise.reject(new Error("Must specify `labelsToAdd` or `labelsToRemove`"))
    return super()

module.exports = ChangeLabelsTask
