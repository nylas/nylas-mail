DatabaseStore = require '../stores/database-store'
Label = require '../models/label'
Folder = require '../models/folder'
Task = require './task'
ChangeFolderTask = require './change-folder-task'
ChangeLabelTask = require './change-labels-task'
SyncbackCategoryTask = require './syncback-category-task'
NylasAPI = require '../nylas-api'
{APIError} = require '../errors'

class DestroyCategoryTask extends Task

  constructor: ({@category}={}) ->
    super

  label: ->
    name = @category.displayName
    if @category instanceof Label
      "Deleting label #{name}..."
    else
      "Deleting folder #{name}..."

  isDependentTask: (other) ->
    (other instanceof ChangeFolderTask) or
    (other instanceof ChangeLabelTask) or
    (other instanceof SyncbackCategoryTask)

  performLocal: ->
    if not @category
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performLocal without @category."))
    @category.isDeleted = true
    DatabaseStore.persistModel @category

  performRemote: ->
    if not @category
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performRemote without @category."))

    if not @category.serverId
      return Promise.reject(new Error("Attempt to call DestroyCategoryTask.performRemote without @category.serverId."))

    if @category instanceof Label
      path = "/labels/#{@category.serverId}"
    else
      path = "/folders/#{@category.serverId}"

    NylasAPI.makeRequest
      path: path
      method: 'DELETE'
      accountId: @category.accountId
      returnsModel: false
    .then ->
      return Promise.resolve(Task.Status.Success)
    .catch APIError, (err) =>
      if err.statusCode in NylasAPI.PermanentErrorCodes
        # Revert isDeleted flag
        @category.isDeleted = false
        DatabaseStore.persistModel(@category).then =>
          NylasEnv.emitError(
            new Error("Deleting category responded with #{err.statusCode}!")
          )
          @_notifyUserOfError()
          return Promise.resolve(Task.Status.Failed)
      else
        return Promise.resolve(Task.Status.Retry)

  _notifyUserOfError: (category = @category) ->
    displayName = category.displayName
    label = if category instanceof Label
      'label'
    else
      'folder'

    msg = "The #{label} #{displayName} could not be deleted."
    if label is 'folder'
      msg += " Make sure the folder you want to delete is empty before deleting it."

    NylasEnv.showErrorDialog(msg)

module.exports = DestroyCategoryTask
