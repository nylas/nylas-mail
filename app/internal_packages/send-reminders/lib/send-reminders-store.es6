import {
  Actions,
  FocusedContentStore,
  SyncbackMetadataTask,
  SyncbackDraftTask,
  DatabaseStore,
  AccountStore,
  TaskQueue,
  Thread,
  Contact,
  DraftFactory,
} from 'nylas-exports'
import NylasStore from 'nylas-store';

import {PLUGIN_ID} from './send-reminders-constants'
import {
  updateReminderMetadata,
  transferReminderMetadataFromDraftToThread,
} from './send-reminders-utils';

class SendRemindersStore extends NylasStore {
  constructor() {
    super();
    this._lastFocusedThread = null;
  }

  activate() {
    this._unsubscribers = [
      FocusedContentStore.listen(this._onFocusedContentChanged),
      Actions.draftDeliverySucceeded.listen(this._onDraftDeliverySucceeded),
      DatabaseStore.listen(this._onDatabaseChanged),
    ];
  }

  deactivate() {
    this._unsubscribers.forEach((unsub) => unsub())
  }

  _sendReminderEmail = async (thread, sentHeaderMessageId) => {
    const account = AccountStore.accountForId(thread.accountId);
    const draft = await DraftFactory.createDraft({
      from: [new Contact({email: account.emailAddress, name: `${account.name} via Mailspring`})],
      to: [account.defaultMe()],
      cc: [],
      pristine: false,
      subject: thread.subject,
      threadId: thread.id,
      accountId: thread.accountId,
      replyToHeaderMessageId: sentHeaderMessageId,
      body: `
        <strong>Mailspring Reminder:</strong> This thread has been moved to the top of
        your inbox by Mailspring because no one has replied to your message</p>.
        <p>--The Mailspring Team</p>`,
    });

    const saveTask = new SyncbackDraftTask({draft})
    Actions.queueTask(saveTask)
    await TaskQueue.waitForPerformLocal(saveTask);
    Actions.sendDraft(draft.headerMessageId);
  }

  _onDraftDeliverySucceeded = ({headerMessageId}) => {
    // when a draft is sent a thread may be created for it for the first time.
    // Move the metadata from the message to the thread for much easier book-keeping.
    transferReminderMetadataFromDraftToThread(headerMessageId);
  }

  _onDatabaseChanged = ({type, objects, objectClass}) => {
    if (objectClass !== Thread.name) {
      return;
    }

    for (const thread of objects) {
      const metadata = thread.metadataForPluginId(PLUGIN_ID);
      if (!metadata || !metadata.expiration) {
        continue;
      }

      // has a new message arrived on the thread? if so, clear the metadata
      if (metadata.lastReplyTimestamp !== new Date(thread.lastMessageReceivedTimestamp).getTime() / 1000) {
        updateReminderMetadata(thread, Object.assign(metadata, {expiration: null, shouldNotify: false}));
        continue;
      }

      // has the metadata expired? If so, send the reminder email and
      // advance metadata into the "notify" phase.
      if (type === 'metadata-expiration' && metadata.expiration <= new Date()) {
        // mark that the email should enter the notification highlight state
        updateReminderMetadata(thread, Object.assign(metadata, {expiration: null, shouldNotify: true}));
        // send an email on the thread, causing the thread to move up in the inbox
        this._sendReminderEmail(thread, metadata.sentHeaderMessageId);
      }
    }
  }

  _onFocusedContentChanged = () => {
    const thread = FocusedContentStore.focused('thread') || null
    const didUnfocusLastThread = (
      (!thread && this._lastFocusedThread) ||
      (thread && this._lastFocusedThread && thread.id !== this._lastFocusedThread.id)
    )
    // When we unfocus a thread that had `shouldNotify == true`, it means that
    // we have acknowledged the notification, or in this case, the reminder. If
    // that's the case, set `shouldNotify` to false.
    if (didUnfocusLastThread) {
      const metadata = this._lastFocusedThread.metadataForPluginId(PLUGIN_ID);
      if (metadata && metadata.shouldNotify) {
        Actions.queueTask(new SyncbackMetadataTask({
          model: this._lastFocusedThread,
          accountId: this._lastFocusedThread.accountId,
          pluginId: PLUGIN_ID,
          value: {shouldNotify: false},
        }));
      }
    }
    this._lastFocusedThread = thread;
  }
}

export default new SendRemindersStore()
