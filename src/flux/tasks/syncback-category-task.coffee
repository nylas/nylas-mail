CategoryStore = require '../stores/category-store'
DatabaseStore = require '../stores/database-store'
Label = require '../models/label'
Folder = require '../models/folder'
{generateTempId} = require '../models/utils'
Task = require './task'
NylasAPI = require '../nylas-api'
{APIError} = require '../errors'

module.exports = class SyncbackCategoryTask extends Task

  constructor: ({@category}={}) ->
    super

  label: ->
    if @category instanceof Label
      "Creating new label..."
    else
      "Creating new folder..."

  performLocal: ->
    # When we send drafts, we don't update anything in the app until
    # it actually succeeds. We don't want users to think messages have
    # already sent when they haven't!
    if not @category
      return Promise.reject(new Error("Attempt to call SyncbackCategoryTask.performLocal without @category."))

    if @_shouldChangeBackwards()
      DatabaseStore.unpersistModel @category
    else
      DatabaseStore.persistModel @category

  performRemote: ->
    if @category instanceof Label
      path = "/labels"
    else
      path = "/folders"

    NylasAPI.makeRequest
      path: path
      method: 'POST'
      accountId: @category.accountId
      body:
        display_name: @category.displayName
      # returnsModel must be false because we want to update the
      # existing model rather than returning a new model.
      returnsModel: false
    .then (json) =>
      # This is where we update the existing model with the newly
      # created serverId.
      @category.serverId = json.id
      DatabaseStore.persistModel @category
    .then ->
      return Promise.resolve(Task.Status.Success)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        @_isReverting = true
        @performLocal().then =>
          return Promise.resolve(Task.Status.Failed)
      else
        return Promise.resolve(Task.Status.Retry)

  _shouldChangeBackwards: ->
    @_isReverting
