Task = require './task'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
Tag = require '../models/tag'
Thread = require '../models/thread'
_ = require 'underscore-plus'
async = require 'async'

class AddRemoveTagsTask extends Task

  constructor: (@threadId, @tagIdsToAdd = [], @tagIdsToRemove = []) ->
    @

  rollbackLocal: ->
    # Run performLocal backwards to undo the tag changes
    a = @tagIdsToAdd
    @tagIdsToAdd = @tagIdsToRemove
    @tagIdsToRemove = a
    @performLocal(-1)

  performLocal:  (versionIncrement = 1) ->
    new Promise (resolve, reject) =>
      return reject(new Error("Attempt to call AddRemoveTagsTask.performLocal without Thread")) unless @threadId

      DatabaseStore.find(Thread, @threadId).then (thread) =>
        return resolve() unless thread

        @namespaceId = thread.namespaceId
        
        # increment the thread version number
        thread.version += versionIncrement

        # remove tags in the remove list
        thread.tags = _.filter thread.tags, (tag) =>
          @tagIdsToRemove.indexOf(tag.id) == -1

        # add tags in the add list
        async.map @tagIdsToAdd, (id, callback) ->
          DatabaseStore.find(Tag, id).then (tag) ->
            callback(null, tag)
        , (err, tags) ->
          for tag in tags
            thread.tags.push(tag) if tag
          DatabaseStore.persistModel(thread).then(resolve)


  performRemote: ->
    new Promise (resolve, reject) =>
      # queue the operation to the server
      atom.inbox.makeRequest {
        path: "/n/#{@namespaceId}/threads/#{@threadId}"
        method: 'PUT'
        body: {
          add_tags: @tagIdsToAdd,
          remove_tags: @tagIdsToRemove
        }
        returnsModel: true
        success: resolve
        error: (apiError) =>
          if "archive" in @tagIdsToAdd
            Actions.postNotification({message: "Failed to archive thread: '#{@thread.subject}'", type: 'error'})
          reject(apiError)
      }

module.exports = AddRemoveTagsTask
