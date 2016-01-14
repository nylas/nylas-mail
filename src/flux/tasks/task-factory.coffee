_ = require 'underscore'
ChangeFolderTask = require './change-folder-task'
ChangeLabelsTask = require './change-labels-task'
ChangeUnreadTask = require './change-unread-task'
ChangeStarredTask = require './change-starred-task'
AccountStore = require '../stores/account-store'
CategoryStore = require '../stores/category-store'

class TaskFactory

  taskForApplyingCategory: ({threads, fromPerspective, category, exclusive}) =>
    # TODO Can not apply to threads across more than one account for now
    account = AccountStore.accountForItems(threads)
    return unless account?

    if account.usesFolders()
      return null unless category
      return new ChangeFolderTask
        folder: category
        threads: threads
    else
      labelsToRemove = []
      if exclusive
        currentLabel = CategoryStore.byId(account, fromPerspective?.categoryId())
        currentLabel ?= CategoryStore.getStandardCategory(account, "inbox")
        labelsToRemove = [currentLabel]

      return new ChangeLabelsTask
        threads: threads
        labelsToRemove: labelsToRemove
        labelsToAdd: [category]

  taskForRemovingCategory: ({threads, fromPerspective, category, exclusive}) =>
    # TODO Can not apply to threads across more than one account for now
    account = AccountStore.accountForItems(threads)
    return unless account?

    if account.usesFolders()
      return new ChangeFolderTask
        folder: CategoryStore.getStandardCategory(account, "inbox")
        threads: threads
    else
      labelsToAdd = []
      if exclusive
        currentLabel = CategoryStore.byId(account, fromPerspective?.categoryId())
        currentLabel ?= CategoryStore.getStandardCategory(account, "inbox")
        labelsToAdd = [currentLabel]

      return new ChangeLabelsTask
        threads: threads
        labelsToRemove: [category]
        labelsToAdd: labelsToAdd

  taskForArchiving: ({threads, fromPerspective}) =>
    category = @_getArchiveCategory(threads)
    @taskForApplyingCategory({threads, fromPerspective, category, exclusive: true})

  taskForUnarchiving: ({threads, fromPerspective}) =>
    category = @_getArchiveCategory(threads)
    @taskForRemovingCategory({threads, fromPerspective, category, exclusive: true})

  taskForMovingToTrash: ({threads, fromPerspective}) =>
    category = @_getTrashCategory(threads)
    @taskForApplyingCategory({threads, fromPerspective, category, exclusive: true})

  taskForMovingFromTrash: ({threads, fromPerspective}) =>
    category = @_getTrashCategory(threads)
    @taskForRemovingCategory({threads, fromPerspective, category, exclusive: true})

  taskForInvertingUnread: ({threads}) =>
    unread = _.every threads, (t) -> _.isMatch(t, {unread: false})
    return new ChangeUnreadTask({threads, unread})

  taskForInvertingStarred: ({threads}) =>
    starred = _.every threads, (t) -> _.isMatch(t, {starred: false})
    return new ChangeStarredTask({threads, starred})

  _getArchiveCategory: (threads) =>
    account = AccountStore.accountForItems(threads)
    return unless account?
    CategoryStore.getArchiveCategory(account)

  _getTrashCategory: (threads) =>
    account = AccountStore.accountForItems(threads)
    return unless account?
    CategoryStore.getTrashCategory(account)

module.exports = new TaskFactory
