_ = require 'underscore'
inflection = require 'inflection'

Task = require './task'
Utils = '../models/utils'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
NamespaceStore = require '../stores/namespace-store'

{APIError} = require '../errors'

# An abstract used to update fields on Nylas objects.
#
# Subclass for individual Nylas types and override the `endpoint` method.
class UpdateNylasObjectsTask extends Task
  constructor: (@objects=[], @newValues={}, @oldValues={}) ->
    super

  # OVERRIDE ME
  endpoint: (obj) ->
    inflection.pluralize(obj.constructor.name.toLowerCase())

  performLocal: ({reverting}={}) ->
    if reverting or @isUndo()
      Promise.map @objects, (obj) =>
        if reverting
          NylasAPI.decrementOptimisticChangeCount(obj.constructor, obj.id)
        else if @isUndo()
          NylasAPI.incrementOptimisticChangeCount(obj.constructor, obj.id)
        oldValue = @oldValues[obj.id]
        return _.extend(obj, oldValue)
      .then(DatabaseStore.persistModels)
    else
      Promise.map @objects, (obj) =>
        NylasAPI.incrementOptimisticChangeCount(obj.constructor, obj.id)
        @oldValues[obj.id] = _.pluck(obj, _.keys(@newValues))
        return _.extend(obj, @newValues)
      .then(DatabaseStore.persistModels)

  performRemote: ->
    nsid = NamespaceStore.current()?.id
    promises = @objects.map (obj) =>
      NylasAPI.makeRequest
        path: "/n/#{nsid}/#{@endpoint(obj)}/#{obj.id}"
        method: 'PUT'
        body: @_requestBody(obj)
        returnsModel: true
        beforeProcessing: (body) ->
          NylasAPI.decrementOptimisticChangeCount(obj.constructor, obj.id)
          return body

    Promise.all(promises)
    .then =>
      return Promise.resolve(Task.Status.Finished)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        @performLocal(reverting: true).then =>
          return Promise.resolve(Task.Status.Finished)
      else
        return Promise.resolve(Task.Status.Retry)

  _requestBody: (obj) ->
    if @isUndo()
      return @oldValues[obj.id] ? {}
    else
      return @newValues

  canBeUndone: -> true

  isUndo: -> @_isUndoTask is true

  createUndoTask: ->
    task = new UpdateNylasObjectsTask(@objects, {}, @oldValues)
    task._isUndoTask = true
    return task

  shouldDequeueOtherTask: (other) ->
    myIds = @objects.map (obj) -> obj.id
    otherIds = @objects.map (obj) -> obj.id

    sameClass = other instanceof UpdateNylasObjectsTask
    sameValues = _.isEqual(@newValues, other.newValues)
    sameObjects = _.isEqual(myIds, otherIds)

    return sameClass and sameValues and sameObjects

module.exports = UpdateNylasObjectsTask
