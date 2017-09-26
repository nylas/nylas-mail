import {
  Thread,
  Message,
  Actions,
  DatabaseStore,
  FeatureUsageStore,
  SyncbackMetadataTask,
} from 'nylas-exports'

import {PLUGIN_ID} from './send-reminders-constants'

const FEATURE_LEXICON = {
  usedUpHeader: "All Reminders Used",
  usagePhrase: "add reminders to",
  iconUrl: "mailspring://send-reminders/assets/ic-send-reminders-modal@2x.png",
};

export function reminderDateFor(draftOrThread) {
  return ((draftOrThread && draftOrThread.metadataForPluginId(PLUGIN_ID)) || {}).expiration;
}

async function incrementMetadataUse(model, expiration) {
  if (reminderDateFor(model)) {
    return true;
  }
  try {
    await FeatureUsageStore.asyncUseFeature(PLUGIN_ID, FEATURE_LEXICON)
  } catch (error) {
    if (error instanceof FeatureUsageStore.NoProAccessError) {
      return false;
    }
  }
  if (expiration) {
    const seconds = Math.round(((new Date(expiration)).getTime() - Date.now()) / 1000)
    Actions.recordUserEvent("Set Reminder", {
      seconds: seconds,
      secondsLog10: Math.log10(seconds),
    });
  }
  return true;
}

function assertMetadataShape(value) {
  const t = Object.assign({}, value);
  if (t.expiration && !(t.expiration instanceof Date)) {
    throw new Error(`"expiration" should always be absent or a date. Received ${t.expiration}`);
  }
  if (t.lastReplyTimestamp && !(t.lastReplyTimestamp < Date.now() / 100)) {
    throw new Error(`"lastReplyTimestamp" should always be a unix timestamp in seconds. Received ${t.lastReplyTimestamp}`);
  }
  delete t.expiration;
  delete t.shouldNotify;
  delete t.sentHeaderMessageId;
  delete t.lastReplyTimestamp;
  if (Object.keys(t).length > 0) {
    throw new Error(`Unexpected keys in metadata: ${Object.keys(t)}`);
  }
}

export async function updateReminderMetadata(thread, metadataValue) {
  assertMetadataShape(metadataValue);

  if (!await incrementMetadataUse(thread, metadataValue.expiration)) {
    return;
  }
  Actions.queueTask(new SyncbackMetadataTask({
    model: thread,
    accountId: thread.accountId,
    pluginId: PLUGIN_ID,
    value: metadataValue,
  }));
}

export async function updateDraftReminderMetadata(draftSession, metadataValue) {
  assertMetadataShape(metadataValue);

  if (!await incrementMetadataUse(draftSession.draft(), metadataValue.expiration)) {
    return;
  }
  draftSession.changes.add({pristine: false})
  draftSession.changes.addPluginMetadata(PLUGIN_ID, metadataValue);
}

export async function transferReminderMetadataFromDraftToThread({accountId, headerMessageId}) {
  const message = await DatabaseStore.findBy(Message, {accountId, headerMessageId})
  if (!message) {
    throw new Error("SendReminders: Could not find message to update")
  }

  const metadata = message.metadataForPluginId(PLUGIN_ID) || {}
  if (!metadata || !metadata.expiration) {
    return;
  }

  const thread = await DatabaseStore.find(Thread, message.threadId);
  updateReminderMetadata(thread, {
    expiration: metadata.expiration,
    sentHeaderMessageId: metadata.sentHeaderMessageId,
    lastReplyTimestamp: new Date(thread.lastMessageReceivedTimestamp).getTime() / 1000,
    shouldNotify: false,
  });
}
