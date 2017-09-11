import moment from 'moment'
import {
  Rx,
  Thread,
  Message,
  Actions,
  Folder,
  NylasAPIHelpers,
  DateUtils,
  DatabaseStore,
  FeatureUsageStore,
  SyncbackMetadataTask,
} from 'nylas-exports'
import {PLUGIN_ID, PLUGIN_NAME} from './send-reminders-constants'


const {DATE_FORMAT_LONG_NO_YEAR} = DateUtils

export function reminderDateForMessage(message) {
  if (!message) {
    return null;
  }
  const messageMetadata = message.metadataForPluginId(PLUGIN_ID) || {};
  return messageMetadata.expiration;
}

async function asyncBuildMetadata({message, thread, expiration} = {}) {
  if (!message) {
    // this is a draft. We can't finalize the metadata because the message
    // may not be attached to the thread sync will place it on.
    return {
      expiration,
    };
  }

  let headerMessageIds = [message.headerMessageId];
  let folderPaths = [];

  // There won't be a thread if this is a newly sent draft that wasn't a reply.
  if (thread) {
    // We need to include the hidden messages so the cloud-worker doesn't think
    // that previously hidden messages are new replies to the thread.
    const messages = await thread.messages({includeHidden: true})
    headerMessageIds = messages.map(msg => msg.headerMessageId)
    folderPaths = thread.folders.map(f => f.path)
  }

  let primary = await DatabaseStore.findBy(Folder, {role: 'all', accountId: message.accountId})
  primary = primary || await DatabaseStore.findBy(Folder, {role: 'inbox', accountId: message.accountId})
  if (primary) {
    folderPaths.unshift(primary.path); // Put it at the front so we check it first
  }

  return {
    expiration,
    folderPaths,
    headerMessageIds,
    replyTo: message.headerMessageId,
    subject: message.subject,
  }
}

export async function asyncUpdateFromSentMessage({headerMessageId}) {
  const message = await DatabaseStore.findBy(Message, {headerMessageId})
  if (!message) {
    throw new Error("SendReminders: Could not find message to update")
  }
  const {expiration} = message.metadataForPluginId(PLUGIN_ID) || {}
  if (!expiration) {
    // This message doesn't have a reminder
    return;
  }

  const thread = message.threadId && await DatabaseStore.find(Thread, message.threadId);
  // thread may not exist if this message wasn't a reply and doesn't have a thread yet

  Actions.queueTask(new SyncbackMetadataTask({
    value: await asyncBuildMetadata({message, thread, expiration}),
    model: message,
    accountId: message.accountId,
    pluginId: PLUGIN_ID,
  }));
}

async function asyncSetReminder(accountId, reminderDate, dateLabel, {message, thread, isDraft, draftSession} = {}) {
  // Only check for feature usage and record metrics if this message doesn't
  // already have a reminder set
  if (!reminderDateForMessage(message)) {
    const lexicon = {
      displayName: "be Reminded",
      usedUpHeader: "All reminders used",
      iconUrl: "mailspring://send-reminders/assets/ic-send-reminders-modal@2x.png",
    }

    try {
      await FeatureUsageStore.asyncUseFeature('send-reminders', {lexicon})
    } catch (error) {
      if (error instanceof FeatureUsageStore.NoProAccessError) {
        return
      }
    }

    if (reminderDate && dateLabel) {
      const remindInSec = Math.round(((new Date(reminderDate)).valueOf() - Date.now()) / 1000)
      Actions.recordUserEvent("Set Reminder", {
        timeInSec: remindInSec,
        timeInLog10Sec: Math.log10(remindInSec),
        label: dateLabel,
      });
    }
  }

  let metadata = {}
  if (reminderDate) {
    metadata = await asyncBuildMetadata({message, thread, expiration: reminderDate})
  } // else: we're clearing the reminder and the metadata should remain empty

  await NylasAPIHelpers.authPlugin(PLUGIN_ID, PLUGIN_NAME, accountId);

  try {
    if (isDraft) {
      if (!draftSession) { throw new Error('setDraftReminder: Must provide draftSession') }
      draftSession.changes.add({pristine: false})
      draftSession.changes.addPluginMetadata(PLUGIN_ID, metadata);
    } else {
      if (!message) { throw new Error('setMessageReminder: Must provide message') }
      Actions.queueTask(new SyncbackMetadataTask({
        model: message,
        accountId: message.accountId,
        pluginId: PLUGIN_ID,
        value: metadata,
      }));
    }
  } catch (error) {
    NylasEnv.reportError(error);
    NylasEnv.showErrorDialog(`Sorry, we were unable to save the reminder for this message. ${error.message}`);
  } finally {
    Actions.closePopover()
  }
}

export function setMessageReminder(accountId, message, reminderDate, dateLabel, thread) {
  return asyncSetReminder(accountId, reminderDate, dateLabel, {isDraft: false, message, thread})
}

export function setDraftReminder(accountId, draftSession, reminderDate, dateLabel) {
  return asyncSetReminder(accountId, reminderDate, dateLabel, {isDraft: true, draftSession})
}


function reminderThreadIdsFromMessages(messages) {
  return Array.from(new Set(
    messages
    .filter((message) => (message.metadataForPluginId(PLUGIN_ID) || {}).expiration != null)
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
    const {expiration} = message.metadataForPluginId(PLUGIN_ID) || {}
    return expiration != null
  })
}

export function getReminderLabel(reminderDate, {fromNow = false, shortFormat = false} = {}) {
  const momentDate = moment(reminderDate);
  if (shortFormat) {
    return momentDate ? `in ${momentDate.fromNow(true)}` : 'now'
  }
  if (fromNow) {
    return momentDate ? `Reminder set for ${momentDate.fromNow(true)} from now` : `Reminder set`;
  }
  return momentDate.format(DATE_FORMAT_LONG_NO_YEAR)
}
