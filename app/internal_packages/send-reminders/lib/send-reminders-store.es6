import {Actions, FocusedContentStore, SyncbackMetadataTask} from 'nylas-exports'
import NylasStore from 'nylas-store';
import {PLUGIN_ID} from './send-reminders-constants'
import {
  getLatestMessage,
  setMessageReminder,
  getLatestMessageWithReminder,
  asyncUpdateFromSentMessage,
  observableForThreadsWithReminders,
} from './send-reminders-utils'


class SendRemindersStore extends NylasStore {
  constructor() {
    super();
    this._lastFocusedThread = null;
  }

  activate() {
    this._unsubscribers = [
      FocusedContentStore.listen(this._onFocusedContentChanged),
      Actions.draftDeliverySucceeded.listen(this._onDraftDeliverySucceeded),
    ]
    this._disposables = [
      observableForThreadsWithReminders().subscribe(this._onThreadsWithRemindersChanged),
    ]
  }

  deactivate() {
    this._unsubscribers.forEach((unsub) => unsub())
    this._disposables.forEach((disp) => disp.dispose())
  }

  _onDraftDeliverySucceeded = ({headerMessageId}) => {
    asyncUpdateFromSentMessage({headerMessageId})
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
      const {shouldNotify} = this._lastFocusedThread.metadataForPluginId(PLUGIN_ID) || {}
      if (shouldNotify) {
        Actions.queueTask(new SyncbackMetadataTask({
          model: this._lastFocusedThread,
          accountId: this._lastFocusedThread.accountId,
          pluginId: PLUGIN_ID,
          value: {shouldNotify: false},
        }));
      }
    }
    this._lastFocusedThread = thread
  }

  _onThreadsWithRemindersChanged = (threads) => {
    // If a new message was received on the thread, clear the reminder
    threads.forEach((thread) => {
      const {accountId} = thread
      thread.messages().then((messages) => {
        const latestMessage = getLatestMessage(thread, messages)
        const latestMessageWithReminder = getLatestMessageWithReminder(thread, messages)
        if (!latestMessageWithReminder) { return }
        if (latestMessage.id !== latestMessageWithReminder.id) {
          setMessageReminder(accountId, latestMessageWithReminder, null)
        }
      })
    })
  }
}

export default new SendRemindersStore()
