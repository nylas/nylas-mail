_ = require 'underscore'
inflection = require 'inflection'
Thread = require '../models/thread'
Message = require '../models/message'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
UpdateNylasObjectsTask = require './update-nylas-objects-task'

class UpdateThreadsTask extends UpdateNylasObjectsTask
  endpoint: -> "threads"

  description: ->
    type = 'thread'
    count = @objects.length
    if count > 1
      type = inflection.pluralize(type)

    if Object.keys(@oldValues).length > 0
      return "Undoing changes to #{count} #{type}"

    if @newValues.unread?
      newState = if @newValues.unread is true then "unread" else "read"
      if count > 1
        return "Marked #{count} #{type} as #{newState}"
      else
        return "Marked as #{newState}"

    if @newValues.starred?
      verb = if @newValues.starred is true then "Starred" else "Unstarred"
      if count > 1
        return "#{verb} #{count} #{type}"
      else
        return "#{verb}"

    "Updated #{count} #{type}"

  performLocal: ({reverting}={}) ->
    threadIds = @objects.map (obj) -> obj.id
    DatabaseStore.findAll(Message).where(
      Message.attributes.threadId.in(threadIds)
    ).then (messages=[]) =>

      messagesToSave = []
      messagesByThread = {}
      for msg in messages
        messagesByThread[msg.threadId] ?= []
        messagesByThread[msg.threadId].push(msg)

      if reverting or @isUndo()
        Promise.map @objects, (obj) =>
          if reverting
            NylasAPI.decrementOptimisticChangeCount(obj.constructor, obj.id)
          else if @isUndo()
            NylasAPI.incrementOptimisticChangeCount(obj.constructor, obj.id)

          for msg in (messagesByThread[obj.id] ? [])
            values = @oldValues[msg.id]

            shouldSave = _.any values, (val, key) ->
              msg[key] isnt val

            if shouldSave
              msgClone = msg.clone()
              for key, val of values
                if key of msgClone and msgClone[key] isnt val
                  msgClone[key] = val

              messagesToSave.push(msgClone)

          oldThreadValues = @oldValues[obj.id]
          threadClone = obj.clone()
          return Promise.resolve(_.extend(threadClone, oldThreadValues))
        .then (updatedObjects) ->
          DatabaseStore.persistModels(updatedObjects)
        .then -> DatabaseStore.persistModels(messagesToSave)
      else
        Promise.map @objects, (obj) =>
          NylasAPI.incrementOptimisticChangeCount(obj.constructor, obj.id)
          @oldValues[obj.id] = _.pluck(obj, _.keys(@newValues))

          for msg in (messagesByThread[obj.id] ? [])
            @oldValues[msg.id] = _.pluck(msg, _.keys(@newValues))

            shouldSave = _.any @newValues, (val, key) ->
              msg[key] isnt val

            if shouldSave
              msgClone = msg.clone()
              for key, val of @newValues
                if key of msgClone and msgClone[key] isnt val
                  msgClone[key] = val

              messagesToSave.push(msgClone)

          threadClone = obj.clone()
          return _.extend(threadClone, @newValues)
        .then (updatedObjects) ->
          DatabaseStore.persistModels(updatedObjects)
        .then -> DatabaseStore.persistModels(messagesToSave)

module.exports = UpdateThreadsTask
