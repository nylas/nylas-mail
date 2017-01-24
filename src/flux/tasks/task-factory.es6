import _ from 'underscore'
import ChangeFolderTask from './change-folder-task'
import ChangeLabelsTask from './change-labels-task'
import ChangeUnreadTask from './change-unread-task'
import ChangeStarredTask from './change-starred-task'
import AccountStore from '../stores/account-store'
import CategoryStore from '../stores/category-store'
import Thread from '../models/thread'
import Category from '../models/category'


const TaskFactory = {

  tasksForApplyingCategories({threads, categoriesToRemove, categoriesToAdd, taskDescription, source}) {
    const byAccount = {}
    const tasks = []

    threads.forEach((thread) => {
      if (!(thread instanceof Thread)) {
        throw new Error("tasksForApplyingCategories: `threads` must be instances of Thread")
      }
      const {accountId} = thread
      if (!byAccount[accountId]) {
        byAccount[accountId] = {
          categoriesToRemove: categoriesToRemove ? categoriesToRemove(accountId) : [],
          categoriesToAdd: categoriesToAdd ? categoriesToAdd(accountId) : [],
          threadsToUpdate: [],
        }
      }
      byAccount[accountId].threadsToUpdate.push(thread)
    })

    _.each(byAccount, (data, accountId) => {
      const catsToAdd = data.categoriesToAdd;
      const catsToRemove = data.categoriesToRemove;
      const threadsToUpdate = data.threadsToUpdate;
      const account = AccountStore.accountForId(accountId);
      if (!(catsToAdd instanceof Array)) {
        throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return an array of Categories")
      }
      if (!(catsToRemove instanceof Array)) {
        throw new Error("tasksForApplyingCategories: `categoriesToRemove` must return an array of Categories")
      }

      if (account.usesFolders()) {
        if (catsToAdd.length === 0) return;
        if (catsToAdd.length > 1) {
          throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return a single `Category` (folder) for Exchange accounts")
        }
        const folder = catsToAdd[0]
        if (!(folder instanceof Category)) {
          throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return a Category")
        }

        tasks.push(new ChangeFolderTask({
          folder,
          source,
          threads: threadsToUpdate,
          taskDescription,
        }))
      } else {
        const labelsToAdd = catsToAdd
        const labelsToRemove = catsToRemove
        if (labelsToAdd.length === 0 && labelsToRemove.length === 0) return;

        tasks.push(new ChangeLabelsTask({
          source,
          threads: threadsToUpdate,
          labelsToRemove,
          labelsToAdd,
          taskDescription,
        }))
      }
    })

    return tasks;
  },

  taskForApplyingCategory({threads, category, source}) {
    const tasks = TaskFactory.tasksForApplyingCategories({
      source,
      threads,
      categoriesToAdd: () => [category],
    })

    if (tasks.length > 1) {
      throw new Error("taskForApplyingCategory: Threads must be from the same account.")
    }

    return tasks[0];
  },

  taskForRemovingCategory({threads, category, source}) {
    const tasks = TaskFactory.tasksForApplyingCategories({
      source,
      threads,
      categoriesToRemove: () => [category],
    })

    if (tasks.length > 1) {
      throw new Error("taskForRemovingCategory: Threads must be from the same account.")
    }

    return tasks[0];
  },

  tasksForMarkingAsSpam({threads, source}) {
    return TaskFactory.tasksForApplyingCategories({
      source,
      threads,
      categoriesToAdd: (accountId) => [CategoryStore.getSpamCategory(accountId)],
    })
  },

  tasksForArchiving({threads, source}) {
    return TaskFactory.tasksForApplyingCategories({
      source,
      threads,
      categoriesToRemove: (accountId) => [
        CategoryStore.getInboxCategory(accountId),
      ],
      categoriesToAdd: (accountId) => [CategoryStore.getArchiveCategory(accountId)],
    })
  },

  tasksForMovingToTrash({threads, source}) {
    return TaskFactory.tasksForApplyingCategories({
      source,
      threads,
      categoriesToAdd: (accountId) => [CategoryStore.getTrashCategory(accountId)],
    })
  },

  taskForInvertingUnread({threads, source}) {
    const unread = _.every(threads, (t) => _.isMatch(t, {unread: false}))
    return new ChangeUnreadTask({threads, unread, source})
  },

  taskForInvertingStarred({threads, source}) {
    const starred = _.every(threads, (t) => _.isMatch(t, {starred: false}))
    return new ChangeStarredTask({threads, starred, source})
  },
}

export default TaskFactory
