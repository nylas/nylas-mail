Folder = require '../models/folder'
Thread = require '../models/thread'
Message = require '../models/message'
DatabaseStore = require '../stores/database-store'
ChangeCategoryTask = require './change-category-task'

# Public: Create a new task to apply labels to a message or thread.
#
# Takes an options array of the form:
#   - `folder` The {Folder} or {Folder} id to move to
#   - `threadIds` Ether an arry of {Thread} ids…
#   - `messageIds` XOR an arry of {Message} ids.
#   - `undoData` Since changing the folder is a destructive action,
#   undo tasks need to store the configuration of what folders messages
#   were in. When creating an undo task, we fill this parameter with
#   that configuration
class ChangeFolderTask extends ChangeCategoryTask

  constructor: ({@folderOrId, @threadIds, @messageIds, @undoData}={}) ->
    @threadIds ?= []; @messageIds ?= []
    @objectIds = @threadIds.concat(@messageIds)
    super

  label: -> "Moving to folder…"

  collectCategories: ->
    if @folderOrId instanceof Folder
      return Promise.props
        folder: Promise.resolve(@folderOrId)
    else
      return Promise.props
        folder: DatabaseStore.find(Folder, @folderOrId.id)

  # Called from super-class's `performRemote`
  rollbackLocal: ->
    # When rolling folders back, we just need to make sure that the
    # `reverting:true` bit is set. This will cause the `localUpdate` logic
    # to correctly use the `undoData` when setting elements
    @performLocal({reverting: true}).then =>
      return Promise.resolve(Task.Status.Finished)

  requestBody: (objectId) ->
    if @threadIds.length > 0
      if @_isUndoTask or @_isReverting
        return folder: @undoData.originalThreadFolders[objectId][0].id
      else
        return folder: @_folderObj.id
    else if @messageIds.length > 0
      if @_isUndoTask or @_isReverting
        return folder: @undoData.originalMessageFolder[objectId].id
      else
        return folder: @_folderObj.id

  createUndoTask: ->
    task = new ChangeFolderTask({@folderOrId, @threadIds, @messageIds, @undoData})
    task._isUndoTask = true
    return task

  # Note that a thread has a collection of folders which represents where
  # each message is. If we're updating a thread, we need to update the
  # messages as well.
  # Called from super-class's `performLocal`
  localUpdateThread: (thread, {folder}) ->
    # We set this here so `performRemote` can access it later
    @_folderObj = folder

    if @_isUndoTask or @_isReverting
      return @_undoLocalUpdateThread(thread)
    else
      @_initUndoData()
      messageQuery = DatabaseStore.findAll(Message, threadId: thread.id)
      childSavePromise = messageQuery.then (messages) =>
        messagesToSave = []
        for message in messages
          if message.folder?.id isnt @_folderObj.id
            @undoData.originalMessageFolder[message.id] = message.folder
            message.folder = @_folderObj
            messagesToSave.push(message)

        DatabaseStore.persistModels(messagesToSave)

      @undoData.originalThreadFolders[thread.id] = thread.folders
      thread.folders = [@_folderObj]
      parentSavePromise = DatabaseStore.persistModel(thread)

      return Promise.all([parentSavePromise, childSavePromise])

  # Called from super-class's `performLocal`
  localUpdateMessage: (message, {folder}) ->
    if @_isUndoTask or @_isReverting
      return @_undoLocalUpdateMessage(message)
    else
      @_folderObj = folder
      @_initUndoData()
      @undoData.originalMessageFolder[message.id] = message.folder
      message.folder = @_folderObj
      return DatabaseStore.persistModel(message)

  _undoLocalUpdateThread: (thread) ->
    messageQuery = DatabaseStore.findAll(Message, threadId: thread.id)
    childSavePromise = messageQuery.then (messages) =>
      messagesToSave = []
      for message in messages
        origFolder = @undoData.originalMessageFolder[message.id]
        if message.folder?.id isnt origFolder?.id
          message.folder = origFolder
          messagesToSave.push(message)
      DatabaseStore.persistModels(messagesToSave)

    thread.folders = @undoData.originalThreadFolders[thread.id]
    parentSavePromise = DatabaseStore.persistModel(thread)

    return Promise.all([parentSavePromise, childSavePromise])

  _undoLocalUpdateMessage: (message) ->
    message.folder = @undoData.originalMessageFolder[message.id]
    return DatabaseStore.persistModel(message)

  # Since we override with a single folder assignment, we need to keep
  # track of the previous folders applied to various messages.
  # This is keyed by a messageId
  _initUndoData: ->
    @undoData ?= {
      originalMessageFolder: {}
      originalThreadFolders: {}
    }

  verifyArgs: ->
    if not @folderOrId
      return Promise.reject(new Error("Must specify a `folder`"))

    if @_isUndoTask and not @undoData
      return Promise.reject(new Error("Must pass an `undoData` to rollback folder changes"))

    return super()

module.exports = ChangeFolderTask
