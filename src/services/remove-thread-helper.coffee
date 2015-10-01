_ = require 'underscore'
CategoryStore = require '../stores/category-store'

ChangeLabelsTask = require './change-labels-task'
ChangeFolderTask = require './change-folder-task'
Actions = require '../actions'

AccountStore = require '../stores/account-store'

class RemoveThreadHelper

  Type:
    Trash: "trash"
    Archive: "archive"

  removeType: ->
    currentAccount = @_currentAccount()
    return null unless currentAccount
    savedType = atom.config.get("core.#{currentAccount.id}.removeType")
    return savedType if savedType

    archiveCategory = CategoryStore.getStandardCategory("archive")
    return @Type.Archive if archiveCategory

    if currentAccount.provider is "gmail"
      return @Type.Archive
    else
      return @Type.Trash

  _currentAccount: -> AccountStore.current() # To stub in testing

  # In the case of folders, "removing" means moving the message to a
  # particular folder
  removalFolder: ->
    if @removeType() is @Type.Trash
      CategoryStore.getStandardCategory("trash")
    else if @removeType() is @Type.Archive
      CategoryStore.getStandardCategory("archive")

  # In the case of labels, "removing" means removing the current label and
  # applying a new label indicating it's in the "removed" state.
  removalLabelToAdd: ->
    if @removeType() is @Type.Trash
      CategoryStore.getStandardCategory("trash")
    else if @removeType() is @Type.Archive
      CategoryStore.getStandardCategory("all")

  getRemovalTask: (threads=[], focusedMailViewFilter) ->
    threads = [threads] unless threads instanceof Array
    account = @_currentAccount()
    return null unless account

    if account.usesFolders()
      removalFolder = @removalFolder()
      if removalFolder
        return new ChangeFolderTask
          folder: removalFolder
          threads: threads
      else
        @_notifyFolderRemovalError()
        return null

    else if account.usesLabels()
      viewCategoryId = focusedMailViewFilter.categoryId()
      currentLabel = CategoryStore.byId(viewCategoryId)
      currentLabel ?= CategoryStore.getStandardCategory("inbox")

      params = {threads}
      params.labelsToRemove = [currentLabel]

      removalLabelToAdd = @removalLabelToAdd()
      if removalLabelToAdd
        params.labelsToAdd = [removalLabelToAdd]

      return new ChangeLabelsTask(params)
    else
      throw new Error("Invalid organizationUnit")

  _notifyFolderRemovalError: ->
    # In the onboarding flow, users should have already created their
    # Removal folder. This should only happen for legacy users or if
    # there's an error somewhere.
    if @removeType() is @Type.Trash
      msg = "There is no Trash folder. Please create a folder called 'Trash' and try again."
    else if @removeType() is @Type.Archive
      msg = "We can't archive your messages because you have no 'Archive' folder. Please create a folder called 'Archive' and try again"
    Actions.postNotification
      type: 'error'
      tag: 'noRemovalFolder'
      sticky: true
      message: msg

module.exports = new RemoveThreadHelper()
