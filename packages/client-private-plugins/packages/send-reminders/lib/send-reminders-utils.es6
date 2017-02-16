import moment from 'moment'
import {
  Rx,
  Thread,
  Message,
  Actions,
  NylasAPIHelpers,
  DateUtils,
  DatabaseStore,
} from 'nylas-exports'
import {PLUGIN_ID, PLUGIN_NAME} from './send-reminders-constants'


const {DATE_FORMAT_LONG_NO_YEAR} = DateUtils

export function reminderDateForMessage(message) {
  if (!message) {
    return null;
  }
  const messageMetadata = message.metadataForPluginId(PLUGIN_ID) || {};
  return messageMetadata.reminderDate;
}

function setReminder(accountId, reminderDate, dateLabel, {message, isDraft, draftSession} = {}) {
  if (reminderDate && dateLabel) {
    const remindInSec = Math.round(((new Date(reminderDate)).valueOf() - Date.now()) / 1000)
    Actions.recordUserEvent("Set Reminder", {
      timeInSec: remindInSec,
      timeInLog10Sec: Math.log10(remindInSec),
      label: dateLabel,
    });
  }

  const metadata = {reminderDate}
  return NylasAPIHelpers.authPlugin(PLUGIN_ID, PLUGIN_NAME, accountId)
  .then(() => {
    if (isDraft) {
      if (!draftSession) { throw new Error('setDraftReminder: Must provide draftSession') }
      draftSession.changes.add({pristine: false})
      draftSession.changes.addPluginMetadata(PLUGIN_ID, metadata);
    } else {
      if (!message) { throw new Error('setMessageReminder: Must provide message') }
      Actions.setMetadata(message, PLUGIN_ID, metadata)
    }
    Actions.closePopover()
  })
  .catch((error) => {
    Actions.closePopover()
    NylasEnv.reportError(error);
    NylasEnv.showErrorDialog(`Sorry, we were unable to save the reminder for this message. ${error.message}`);
  });
}

export function setMessageReminder(accountId, message, reminderDate, dateLabel) {
  return setReminder(accountId, reminderDate, dateLabel, {isDraft: false, message})
}

export function setDraftReminder(accountId, draftSession, reminderDate, dateLabel) {
  return setReminder(accountId, reminderDate, dateLabel, {isDraft: true, draftSession})
}


function reminderThreadIdsFromMessages(messages) {
  return Array.from(new Set(
    messages
    .filter((message) => (message.metadataForPluginId(PLUGIN_ID) || {}).reminderDate != null)
    .map(({threadId}) => threadId)
    .filter((threadId) => threadId != null)
  ))
}

export function observableForThreadsWithReminders(accountIds = [], {emitIds = false} = {}) {
  let messagesQuery = (
    DatabaseStore.findAll(Message)
    .where(Message.attributes.pluginMetadata.contains(PLUGIN_ID))
  )
  if (accountIds.length === 1) {
    messagesQuery = messagesQuery.where({accountId: accountIds[0]})
  }
  const messages$ = Rx.Observable.fromQuery(messagesQuery)
  if (emitIds) {
    return messages$.map((messages) => reminderThreadIdsFromMessages(messages))
  }
  return messages$.flatMapLatest((messages) => {
    const threadIds = reminderThreadIdsFromMessages(messages)
    const threadsQuery = (
      DatabaseStore.findAll(Thread)
      .where({id: threadIds})
      .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
    )
    return Rx.Observable.fromQuery(threadsQuery)
  })
}

export function getLatestMessage(thread, messages) {
  const msgs = messages || thread.__messages || [];
  return msgs[msgs.length - 1]
}

export function getLatestMessageWithReminder(thread, messages) {
  const msgs = (messages || thread.__messages || []).slice().reverse();
  return msgs.find((message) => {
    const {reminderDate} = message.metadataForPluginId(PLUGIN_ID) || {}
    return reminderDate != null
  })
}

export function getReminderLabel(reminderDate, {fromNow = false, shortFormat = false} = {}) {
  const momentDate = DateUtils.futureDateFromString(reminderDate);
  if (shortFormat) {
    return momentDate ? `in ${momentDate.fromNow(true)}` : 'now'
  }
  if (fromNow) {
    return momentDate ? `Reminder set for ${momentDate.fromNow(true)} from now` : `Reminder set`;
  }
  return moment(reminderDate).format(DATE_FORMAT_LONG_NO_YEAR)
}
