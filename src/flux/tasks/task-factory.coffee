_ = require 'underscore'
ChangeFolderTask = require './change-folder-task'
ChangeLabelsTask = require './change-labels-task'
ChangeUnreadTask = require './change-unread-task'
ChangeStarredTask = require './change-starred-task'
AccountStore = require '../stores/account-store'
CategoryStore = require '../stores/category-store'

class TaskFactory

  taskForApplyingCategory: ({threads, fromView, category, exclusive}) =>
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
        currentLabel = CategoryStore.byId(fromView?.categoryId())
        currentLabel ?= CategoryStore.getStandardCategory(account, "inbox")
        labelsToRemove = [currentLabel]

      return new ChangeLabelsTask
        threads: threads
        labelsToRemove: labelsToRemove
        labelsToAdd: [category]

  taskForRemovingCategory: ({threads, fromView, category, exclusive}) =>
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
        currentLabel = CategoryStore.byId(fromView?.categoryId())
        currentLabel ?= CategoryStore.getStandardCategory(account, "inbox")
        labelsToAdd = [currentLabel]

      return new ChangeLabelsTask
        threads: threads
        labelsToRemove: [category]
        labelsToAdd: labelsToAdd

  taskForArchiving: ({threads, fromView}) =>
    category = @_archiveCategory()
    @taskForApplyingCategory({threads, fromView, category, exclusive: true})

  taskForUnarchiving: ({threads, fromView}) =>
    category = @_archiveCategory()
    @taskForRemovingCategory({threads, fromView, category, exclusive: true})

  taskForMovingToTrash: ({threads, fromView}) =>
    category = @_trashCategory()
    @taskForApplyingCategory({threads, fromView, category, exclusive: true})

  taskForMovingFromTrash: ({threads, fromView}) =>
    category = @_trashCategory()
    @taskForRemovingCategory({threads, fromView, category, exclusive: true})

  taskForInvertingUnread: ({threads}) =>
    unread = _.every threads, (t) -> _.isMatch(t, {unread: false})
    return new ChangeUnreadTask({threads, unread})

  taskForInvertingStarred: ({threads}) =>
    starred = _.every threads, (t) -> _.isMatch(t, {starred: false})
    return new ChangeStarredTask({threads, starred})

  _archiveCategory: (threads) =>
    account = AccountStore.accountForItems(threads)
    return unless account?
    CategoryStore.getArchiveCategory(account)

  _trashCategory: (threads) =>
    account = AccountStore.accountForItems(threads)
    return unless account?
    CategoryStore.getTrashCategory(account)

module.exports = new TaskFactory
