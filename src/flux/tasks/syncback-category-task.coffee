CategoryStore = require '../stores/category-store'
DatabaseStore = require '../stores/database-store'
AccountStore = require '../stores/account-store'
{generateTempId} = require '../models/utils'
Task = require './task'
NylasAPI = require '../nylas-api'
{APIError} = require '../errors'

module.exports = class SyncbackCategoryTask extends Task

  constructor: ({@category, @displayName}={}) ->
    super

  label: ->
    if @category.serverId
      "Updating #{@category.displayType()}..."
    else
      "Creating new #{@category.displayType()}..."

  performLocal: ->
    if not @category
      return Promise.reject(new Error("Attempt to call SyncbackCategoryTask.performLocal without @category."))

    isUpdating = @category.serverId

    DatabaseStore.inTransaction (t) =>
      if @_isReverting
        if isUpdating
          @category.displayName = @_initialDisplayName
          t.persistModel @category
        else
          t.unpersistModel @category
      else
        if isUpdating and @displayName
          @_initialDisplayName = @category.displayName
          @category.displayName = @displayName
        t.persistModel @category

  performRemote: ->
    if AccountStore.accountForId(@category.accountId).usesLabels()
      path = "/labels"
    else
      path = "/folders"

    if @category.serverId
      method = 'PUT'
      path += "/#{@category.serverId}"
    else
      method = 'POST'

    NylasAPI.makeRequest
      path: path
      method: method
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
      DatabaseStore.inTransaction (t) =>
        t.persistModel(@category)
    .then ->
      return Promise.resolve(Task.Status.Success)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        @_isReverting = true
        @performLocal().then =>
          return Promise.resolve(Task.Status.Failed)
      else
        return Promise.resolve(Task.Status.Retry)

