import moment from 'moment';
import {
  Actions,
  Label,
  DateUtils,
  TaskFactory,
  CategoryStore,
  ChangeLabelsTask,
  ChangeFolderTask,
} from 'mailspring-exports';

export function snoozedUntilMessage(snoozeDate, now = moment()) {
  let message = 'Snoozed';
  if (snoozeDate) {
    let dateFormat = DateUtils.DATE_FORMAT_SHORT;
    const date = moment(snoozeDate);
    const hourDifference = moment.duration(date.diff(now)).asHours();

    if (hourDifference < 24) {
      dateFormat = dateFormat.replace('MMM D, ', '');
    }
    if (date.minutes() === 0) {
      dateFormat = dateFormat.replace(':mm', '');
    }

    message += ` until ${DateUtils.format(date, dateFormat)}`;
  }
  return message;
}

export function moveThreads(threads, { snooze, description } = {}) {
  const tasks = TaskFactory.tasksForThreadsByAccountId(threads, (accountThreads, accountId) => {
    const snoozeCat = CategoryStore.getCategoryByRole(accountId, 'snoozed');
    const inboxCat = CategoryStore.getInboxCategory(accountId);

    if (snoozeCat instanceof Label) {
      return new ChangeLabelsTask({
        source: 'Snooze Move',
        threads: accountThreads,
        taskDescription: description,
        labelsToAdd: snooze ? [snoozeCat] : [inboxCat],
        labelsToRemove: snooze ? [inboxCat] : [snoozeCat],
      });
    }
    return new ChangeFolderTask({
      source: 'Snooze Move',
      threads: accountThreads,
      taskDescription: description,
      folder: snooze ? snoozeCat : inboxCat,
    });
  });

  Actions.queueTasks(tasks);
}

export function markUnreadIfSet(threads, source) {
  if (AppEnv.config.get('core.notifications.unreadOnSnooze')) {
    Actions.queueTask(
      TaskFactory.taskForSettingUnread({
        unread: true,
        threads: threads,
        source: source,
        canBeUndone: true,
      })
    );
  }
}
