import moment from 'moment';
import {
  Actions,
  Thread,
  Label,
  DateUtils,
  TaskFactory,
  CategoryStore,
  DatabaseStore,
  ChangeLabelsTask,
  ChangeFolderTask,
  TaskQueue,
} from 'nylas-exports';

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

  moveThreads(threads, {snooze, description} = {}) {
    const tasks = TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => {
      const snoozeCat = CategoryStore.getCategoryByRole(accountId, 'snoozed');
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

  moveThreadsToSnooze(threads, snoozeDate) {
    return SnoozeUtils.moveThreads(threads, {
      snooze: true,
      description: SnoozeUtils.snoozedUntilMessage(snoozeDate),
    })
  },

  moveThreadsFromSnooze(threads) {
    return SnoozeUtils.moveThreads(threads, {
      snooze: false,
      description: 'Unsnoozed',
    })
  },
}

export default SnoozeUtils
