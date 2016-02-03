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
      account = AccountStore.accountForId(accountId)

      if account.usesFolders()
        continue unless categoryToAdd
        tasks.push new ChangeFolderTask
          folder: categoryToAdd
          threads: threads
      else
        labelsToAdd = if categoryToAdd then [categoryToAdd] else []
        tasks.push new ChangeLabelsTask
          threads: threads
          labelsToRemove: categoriesToRemove
          labelsToAdd: labelsToAdd

    return tasks

  taskForApplyingCategory: ({threads, category}) =>
    tasks = @tasksForApplyingCategories
      threads: threads
      categoryToAdd: (accountId) -> category

    if tasks.length > 1
      throw new Error("taskForApplyingCategory: Threads must be from the same account.")

    return tasks[0]

  tasksForRemovingCategories: ({threads, categories, moveToFinishedCategory}) =>
    return unless categories
    @tasksForApplyingCategories
      threads: threads
      categoriesToRemove: (accountId) ->
        _.filter(categories, _.matcher({accountId}))
      categoryToAdd: (accountId) ->
        account = AccountStore.accountForId(accountId)
        destination = account.defaultFinishedCategory()
        if account.usesFolders()
          # If we are removing a folder, it means we are moving the threads to the
          # trash or to the archive, depending on the user setting, and
          # regardless of the moveToFinishedCategory option
          return destination
        else
          # Otherwise, we don't want to add any labels, unless we are moving the
          # threads
          return destination if moveToFinishedCategory
          return null

  taskForRemovingCategory: ({threads, category}) =>
    tasks = @tasksForRemovingCategories({threads, categories: [category]})
    if tasks.length > 1
      throw new Error("taskForRemovingCategory: Threads must be from the same account.")

    return tasks[0]

  tasksForMovingToInbox: ({threads, fromPerspective}) =>
    @tasksForApplyingCategories
      threads: threads,
      categoriesToRemove: (accountId) -> _.filter(fromPerspective.categories(), _.matcher({accountId}))
      categoryToAdd: (accountId) -> CategoryStore.getInboxCategory(accountId)

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
