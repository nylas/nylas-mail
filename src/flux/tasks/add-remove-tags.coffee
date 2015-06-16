Task = require './task'
NylasAPI = require '../nylas-api'
DatabaseStore = require '../stores/database-store'
Actions = require '../actions'
Tag = require '../models/tag'
Thread = require '../models/thread'
_ = require 'underscore'
async = require 'async'

module.exports =
class AddRemoveTagsTask extends Task

  constructor: (@thread, @tagIdsToAdd = [], @tagIdsToRemove = []) ->
    super

  label: ->
    "Applying tags..."

  performLocal:  (versionIncrement = 1) ->
    new Promise (resolve, reject) =>
      if not @thread or not @thread instanceof Thread
        return reject(new Error("Attempt to call AddRemoveTagsTask.performLocal without Thread"))

      # collect all of the models we need.
      needed = {}
      for id in @tagIdsToAdd
        if id in ['archive', 'unread', 'inbox', 'unseen']
          needed["tag-#{id}"] = new Tag(id: id, name: id)
        else
          needed["tag-#{id}"] = DatabaseStore.find(Tag, id)

      Promise.props(needed).then (objs) =>
        # Always apply our changes to a new copy of the thread.
        # In some scenarios it may actually be frozen
        thread = new Thread(@thread)

        @namespaceId = thread.namespaceId

        # increment the thread version number
        thread.version += versionIncrement

        # filter the tags array to exclude tags we're removing and tags we're adding.
        # Removing before adding is a quick way to make sure they're only in the set
        # once. (super important)
        thread.tags = _.filter thread.tags, (tag) =>
          @tagIdsToRemove.indexOf(tag.id) is -1 and @tagIdsToAdd.indexOf(tag.id) is -1

        # add tags in the add list
        for id in @tagIdsToAdd
          tag = objs["tag-#{id}"]
          thread.tags.push(tag) if tag

        DatabaseStore.persistModel(thread).then(resolve)

  performRemote: ->
    new Promise (resolve, reject) =>
      # queue the operation to the server
      NylasAPI.makeRequest
        path: "/n/#{@namespaceId}/threads/#{@thread.id}"
        method: 'PUT'
        body:
          add_tags: @tagIdsToAdd,
          remove_tags: @tagIdsToRemove
        returnsModel: true
        success: resolve
        error: reject

  onAPIError: (apiError) ->
    if apiError.response.statusCode is 404
      # Do nothing - NylasAPI will destroy the object.
    else
      @_rollbackLocal()
    Promise.resolve()

  _rollbackLocal: ->
    # Run performLocal backwards to undo the tag changes
    a = @tagIdsToAdd
    @tagIdsToAdd = @tagIdsToRemove
    @tagIdsToRemove = a
    @performLocal(-1)
