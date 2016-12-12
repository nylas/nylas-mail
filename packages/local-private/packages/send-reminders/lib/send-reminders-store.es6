import {Actions, FocusedContentStore} from 'nylas-exports'
import {PLUGIN_ID} from './send-reminders-constants'
import {
  getLatestMessage,
  setMessageReminder,
  getLatestMessageWithReminder,
  observableForThreadsWithReminders,
} from './send-reminders-utils'


class SendRemindersStore {

  activate() {
    this._lastFocusedThread = null
    this._unsubscribers = [
      FocusedContentStore.listen(this._onFocusedContentChanged),
    ]
    this._disposables = [
      observableForThreadsWithReminders().subscribe(this._onThreadsWithRemindersChanged),
    ]
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
        const nextMetadata = {shouldNotify: false}
        Actions.setMetadata(this._lastFocusedThread.clone(), PLUGIN_ID, nextMetadata)
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

  deactivate() {
    this._unsubscribers.forEach((unsub) => unsub())
    this._disposables.forEach((disp) => disp.dispose())
  }
}

export default new SendRemindersStore()
