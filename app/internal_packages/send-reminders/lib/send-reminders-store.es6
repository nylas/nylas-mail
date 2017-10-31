import {
  Actions,
  FocusedContentStore,
  SendDraftTask,
  DatabaseStore,
  Thread,
  DraftFactory,
} from 'mailspring-exports';
import MailspringStore from 'mailspring-store';

import { PLUGIN_ID } from './send-reminders-constants';
import {
  updateReminderMetadata,
  transferReminderMetadataFromDraftToThread,
} from './send-reminders-utils';

class SendRemindersStore extends MailspringStore {
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
    this._unsubscribers.forEach(unsub => unsub());
  }

  _sendReminderEmail = async (thread, sentHeaderMessageId) => {
    const body = `
      <strong>Mailspring Reminder:</strong> This thread has been moved to the top of
      your inbox by Mailspring because no one has replied to your message.</p>
      <p>--The Mailspring Team</p>`;

    const draft = await DraftFactory.createDraftForResurfacing(thread, sentHeaderMessageId, body);
    Actions.queueTask(new SendDraftTask({ draft, silent: true }));
  };

  _onDraftDeliverySucceeded = ({ headerMessageId, accountId }) => {
    // when a draft is sent a thread may be created for it for the first time.
    // Move the metadata from the message to the thread for much easier book-keeping.
    transferReminderMetadataFromDraftToThread({ headerMessageId, accountId });
  };

  _onDatabaseChanged = ({ type, objects, objectClass }) => {
    if (objectClass !== Thread.name) {
      return;
    }

    for (const thread of objects) {
      const metadata = thread.metadataForPluginId(PLUGIN_ID);
      if (!metadata || !metadata.expiration) {
        continue;
      }

      // has a new message arrived on the thread? if so, clear the metadata completely
      if (
        metadata.lastReplyTimestamp !==
        new Date(thread.lastMessageReceivedTimestamp).getTime() / 1000
      ) {
        updateReminderMetadata(thread, {});
        continue;
      }

      // has the metadata expired? If so, send the reminder email and
      // advance metadata into the "notify" phase.
      if (type === 'metadata-expiration' && metadata.expiration <= new Date()) {
        // mark that the email should enter the notification highlight state
        updateReminderMetadata(
          thread,
          Object.assign(metadata, { expiration: null, shouldNotify: true })
        );
        // send an email on the thread, causing the thread to move up in the inbox
        this._sendReminderEmail(thread, metadata.sentHeaderMessageId);
      }
    }
  };

  _onFocusedContentChanged = () => {
    const thread = FocusedContentStore.focused('thread') || null;
    const didUnfocusLastThread =
      (!thread && this._lastFocusedThread) ||
      (thread && this._lastFocusedThread && thread.id !== this._lastFocusedThread.id);
    // When we unfocus a thread that had `shouldNotify == true`, it means that
    // we have acknowledged the notification, or in this case, the reminder. If
    // that's the case, set `shouldNotify` to false.
    if (didUnfocusLastThread) {
      const metadata = this._lastFocusedThread.metadataForPluginId(PLUGIN_ID);
      if (metadata && metadata.shouldNotify) {
        updateReminderMetadata(this._lastFocusedThread, {});
      }
    }
    this._lastFocusedThread = thread;
  };
}

export default new SendRemindersStore();
