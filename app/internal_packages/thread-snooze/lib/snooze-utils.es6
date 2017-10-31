import moment from 'moment';
import {
  Actions,
  Label,
  DateUtils,
  TaskFactory,
  CategoryStore,
  ChangeLabelsTask,
  ChangeFolderTask,
  DraftFactory,
  SendDraftTask,
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
        canBeUndone: snooze ? true : false,
      });
    }
    return new ChangeFolderTask({
      source: 'Snooze Move',
      threads: accountThreads,
      taskDescription: description,
      folder: snooze ? snoozeCat : inboxCat,
      canBeUndone: snooze ? true : false,
    });
  });

  Actions.queueTasks(tasks);
}

export async function markUnreadOrResurfaceThreads(threads, source) {
  if (AppEnv.config.get('core.notifications.unsnoozeToTop')) {
    // send a hidden email that will mark the thread as unread and bring it
    // to the top of your inbox in any mail client
    const body = `
    <strong>Mailspring Reminder:</strong> This thread has been moved to the top of
    your inbox by Mailspring.</p>
    <p>--The Mailspring Team</p>`;

    for (const thread of threads) {
      const draft = await DraftFactory.createDraftForResurfacing(thread, null, body);
      Actions.queueTask(new SendDraftTask({ draft, silent: true }));
    }
  } else {
    // just mark the threads as unread (unless they're all already unread)
    if (!threads.some(t => !t.unread)) {
      return;
    }
    Actions.queueTask(
      TaskFactory.taskForSettingUnread({
        unread: true,
        threads: threads,
        source: source,
        canBeUndone: false,
      })
    );
  }
}
