import moment from 'moment';
import {
  Actions,
  Thread,
  Label,
  DateUtils,
  TaskFactory,
  AccountStore,
  CategoryStore,
  DatabaseStore,
  SyncbackCategoryTask,
  ChangeLabelsTask,
  ChangeFolderTask,
  TaskQueue,
  FolderSyncProgressStore,
} from 'nylas-exports';
import {SNOOZE_CATEGORY_NAME} from './snooze-constants'

const {DATE_FORMAT_SHORT} = DateUtils

const SnoozeUtils = {
  snoozedUntilMessage(snoozeDate, now = moment()) {
    let message = 'Snoozed'
    if (snoozeDate) {
      let dateFormat = DATE_FORMAT_SHORT
      const date = moment(snoozeDate)
      const hourDifference = moment.duration(date.diff(now)).asHours()

      if (hourDifference < 24) {
        dateFormat = dateFormat.replace('MMM D, ', '');
      }
      if (date.minutes() === 0) {
        dateFormat = dateFormat.replace(':mm', '');
      }

      message += ` until ${DateUtils.format(date, dateFormat)}`;
    }
    return message;
  },

  async createSnoozeCategory(accountId, name = SNOOZE_CATEGORY_NAME) {
    const task = new SyncbackCategoryTask({
      path: name,
      accountId: accountId,
    })

    Actions.queueTask(task)
    const finishedTask = await TaskQueue.waitForPerformRemote(task);
    return finishedTask.created;
  },

  async getSnoozeCategory(accountId, categoryName = SNOOZE_CATEGORY_NAME) {
    await FolderSyncProgressStore.whenCategoryListSynced(accountId)
    const allCategories = CategoryStore.categories(accountId)
    const category = allCategories.find(c => c.displayName === categoryName)
    if (category) {
      return category;
    }
    return SnoozeUtils.createSnoozeCategory(accountId, categoryName)
  },

  getSnoozeCategoriesByAccount(accounts = AccountStore.accounts()) {
    const snoozeCategoriesByAccountId = {}
    accounts.forEach(({id}) => {
      if (snoozeCategoriesByAccountId[id] != null) return;
      snoozeCategoriesByAccountId[id] = SnoozeUtils.getSnoozeCategory(id)
    })
    return Promise.props(snoozeCategoriesByAccountId)
  },

  moveThreads(threads, {snooze, snoozeCategoriesByAccountId, description} = {}) {
    const tasks = TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => {
      const snoozeCat = snoozeCategoriesByAccountId[accountId];
      const inboxCat = CategoryStore.getInboxCategory(accountId);

      if (snoozeCat instanceof Label) {
        return new ChangeLabelsTask({
          source: "Snooze Move",
          threads: accountThreads,
          taskDescription: description,
          labelsToAdd: snooze ? [snoozeCat] : [inboxCat],
          labelsToRemove: snooze ? [inboxCat] : [snoozeCat],
        });
      }
      return new ChangeFolderTask({
        source: "Snooze Move",
        threads: accountThreads,
        taskDescription: description,
        folder: snooze ? snoozeCat : inboxCat,
      });
    });

    Actions.queueTasks(tasks);
    const promises = tasks.map(task => TaskQueue.waitForPerformRemote(task))

    // Resolve with the updated threads
    return (
      Promise.all(promises).then(() => {
        return DatabaseStore.modelify(Thread, threads.map(t => t.id))
      })
    )
  },

  moveThreadsToSnooze(threads, snoozeCategoriesByAccountId, snoozeDate) {
    return SnoozeUtils.moveThreads(threads, {
      snooze: true,
      snoozeCategoriesByAccountId,
      description: SnoozeUtils.snoozedUntilMessage(snoozeDate),
    })
  },

  moveThreadsFromSnooze(threads, snoozeCategoriesByAccountId) {
    return SnoozeUtils.moveThreads(threads, {
      snooze: false,
      snoozeCategoriesByAccountId,
      description: 'Unsnoozed',
    })
  },
}

export default SnoozeUtils
