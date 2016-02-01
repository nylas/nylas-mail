_ = require 'underscore'
ChangeFolderTask = require './change-folder-task'
ChangeLabelsTask = require './change-labels-task'
ChangeUnreadTask = require './change-unread-task'
ChangeStarredTask = require './change-starred-task'
AccountStore = require '../stores/account-store'
CategoryStore = require '../stores/category-store'
Thread = require '../models/thread'

class TaskFactory

  tasksForApplyingCategories: ({threads, categoriesToRemove, categoryToAdd}) =>
    byAccount = {}
    tasks = []

    for thread in threads
      unless thread instanceof Thread
        throw new Error("tasksForApplyingCategories: `threads` must be instances of Thread")

      accountId = thread.accountId
      byAccount[accountId] ?=
        categoriesToRemove: categoriesToRemove?(accountId) ? []
        categoryToAdd: categoryToAdd(accountId)
        threads: []
      byAccount[accountId].threads.push(thread)

    for accountId, {categoryToAdd, categoriesToRemove, threads} of byAccount
      continue unless categoryToAdd and categoriesToRemove

      account = AccountStore.accountForId(accountId)
      if account.usesFolders()
        tasks.push new ChangeFolderTask
          folder: categoryToAdd
          threads: threads
      else
        tasks.push new ChangeLabelsTask
          threads: threads
          labelsToRemove: categoriesToRemove
          labelsToAdd: [categoryToAdd]

    return tasks

  taskForApplyingCategory: ({threads, category}) =>
    tasks = @tasksForApplyingCategories
      threads: threads
      categoryToAdd: (accountId) -> category

    if tasks.length > 1
      throw new Error("taskForApplyingCategory: Threads must be from the same account.")

    return tasks[0]

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
        currentLabel = fromPerspective?.category()
        currentLabel ?= CategoryStore.getStandardCategory(account, "inbox")
        labelsToAdd = [currentLabel]

      return new ChangeLabelsTask
        threads: threads
        labelsToRemove: [category]
        labelsToAdd: labelsToAdd

  tasksForMarkingAsSpam: ({threads}) =>
    @tasksForApplyingCategories
      threads: threads,
      categoriesToRemove: (accountId) ->
        [CategoryStore.getStandardCategory(accountId, 'inbox')]
      categoryToAdd: (accountId) -> CategoryStore.getStandardCategory(accountId, 'spam')

  tasksForArchiving: ({threads, fromPerspective}) =>
    @tasksForApplyingCategories
      threads: threads,
      categoriesToRemove: (accountId) -> _.filter(fromPerspective.categories(), _.matcher({accountId}))
      categoryToAdd: (accountId) -> CategoryStore.getArchiveCategory(accountId)

  tasksForMovingToTrash: ({threads, fromPerspective}) =>
    @tasksForApplyingCategories
      threads: threads,
      categoriesToRemove: (accountId) -> _.filter(fromPerspective.categories(), _.matcher({accountId}))
      categoryToAdd: (accountId) -> CategoryStore.getTrashCategory(accountId)

  taskForInvertingUnread: ({threads}) =>
    unread = _.every threads, (t) -> _.isMatch(t, {unread: false})
    return new ChangeUnreadTask({threads, unread})

  taskForInvertingStarred: ({threads}) =>
    starred = _.every threads, (t) -> _.isMatch(t, {starred: false})
    return new ChangeStarredTask({threads, starred})

module.exports = new TaskFactory
