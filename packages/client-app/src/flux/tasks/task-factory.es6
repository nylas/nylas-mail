import _ from 'underscore'
import ChangeFolderTask from './change-folder-task'
import ChangeLabelsTask from './change-labels-task'
import ChangeUnreadTask from './change-unread-task'
import ChangeStarredTask from './change-starred-task'
import CategoryStore from '../stores/category-store'
import Thread from '../models/thread'
import Category from '../models/category'
import Label from '../models/label';

function threadsByAccount(threads) {
  const byAccount = {}
  threads.forEach((thread) => {
    if (!(thread instanceof Thread)) {
      throw new Error("tasksForApplyingCategories: `threads` must be instances of Thread")
    }
    const {accountId} = thread;
    if (!byAccount[accountId]) {
      byAccount[accountId] = {accountThreads: [], accountId: accountId};
    }
    byAccount[accountId].accountThreads.push(thread)
  })
  return Object.values(byAccount);
}

const TaskFactory = {
  tasksForApplyingCategories({threads, categoriesToRemove, categoriesToAdd, taskDescription, source}) {
    const tasks = [];

    threadsByAccount(threads).forEach(({accountThreads, accountId}) => {
      const catsToAdd = categoriesToAdd ? categoriesToAdd(accountId) : [];
      const catsToRemove = categoriesToRemove ? categoriesToRemove(accountId) : [];

      if (!(catsToAdd instanceof Array)) {
        throw new Error("tasksForApplyingCategories: `categoriesToAdd` must return an array of Categories")
      }
      if (!(catsToRemove instanceof Array)) {
        throw new Error("tasksForApplyingCategories: `categoriesToRemove` must return an array of Categories")
      }

      const usingLabels = [].concat(catsToAdd, catsToRemove).pop() instanceof Label;

      if (usingLabels) {
        if (catsToAdd.length === 0 && catsToRemove.length === 0) {
          return;
        }

        tasks.push(new ChangeLabelsTask({
          source,
          threads: accountThreads,
          labelsToRemove: catsToRemove,
          labelsToAdd: catsToAdd,
          taskDescription,
        }))
      } else {
        if (catsToAdd.length === 0) {
          return;
        }
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
          threads: accountThreads,
          taskDescription,
        }));
      }
    })

    return tasks;
  },

  tasksForMarkingAsSpam({threads, source}) {
    return threadsByAccount(threads).map(({accountThreads, accountId}) => {
      return new ChangeFolderTask({
        folder: CategoryStore.getSpamCategory(accountId),
        threads: accountThreads,
        source,
      });
    })
  },

  tasksForMarkingNotSpam({threads, source}) {
    return threadsByAccount(threads).map(({accountThreads, accountId}) => {
      const inbox = CategoryStore.getInboxCategory(accountId);
      if (inbox instanceof Label) {
        return new ChangeFolderTask({
          folder: CategoryStore.getAllMailCategory(accountId),
          threads: accountThreads,
          source,
        });
      }
      return new ChangeFolderTask({
        folder: inbox,
        threads: accountThreads,
        source,
      });
    });
  },

  tasksForArchiving({threads, source}) {
    return threadsByAccount(threads).map(({accountThreads, accountId}) => {
      const inbox = CategoryStore.getInboxCategory(accountId);
      if (inbox instanceof Label) {
        return new ChangeLabelsTask({
          labelsToRemove: [inbox],
          labelsToAdd: [],
          threads: accountThreads,
          source,
        });
      }
      return new ChangeFolderTask({
        folder: CategoryStore.getArchiveCategory(accountId),
        threads: accountThreads,
        source,
      });
    });
  },

  tasksForMovingToTrash({threads, source}) {
    return threadsByAccount(threads).map(({accountThreads, accountId}) => {
      return new ChangeFolderTask({
        folder: CategoryStore.getTrashCategory(accountId),
        threads: accountThreads,
        source,
      });
    })
  },

  taskForInvertingUnread({threads, source, canBeUndone}) {
    const unread = _.every(threads, (t) => _.isMatch(t, {unread: false}))
    return new ChangeUnreadTask({threads, unread, source, canBeUndone})
  },

  taskForSettingUnread({threads, unread, source, canBeUndone}) {
    return new ChangeUnreadTask({threads, unread, source, canBeUndone})
  },

  taskForInvertingStarred({threads, source}) {
    const starred = _.every(threads, (t) => _.isMatch(t, {starred: false}))
    return new ChangeStarredTask({threads, starred, source})
  },
}

export default TaskFactory
