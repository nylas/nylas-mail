import {
  Thread,
  DatabaseStore,
  MutableQuerySubscription,
} from 'nylas-exports'
import {observableForThreadsWithReminders} from './send-reminders-utils'


class SendRemindersQuerySubscription extends MutableQuerySubscription {

  constructor(accountIds) {
    super(null, {emitResultSet: true})
    this._disposable = null
    this._accountIds = accountIds
    setImmediate(() => this.fetchThreadsWithReminders())
  }

  replaceRange = () => {
    // TODO
  }

  fetchThreadsWithReminders() {
    this._disposable = observableForThreadsWithReminders(this._accountIds, {emitIds: true})
    .subscribe((threadIds) => {
      const threadQuery = (
        DatabaseStore.findAll(Thread)
        .where({id: threadIds})
        .order(Thread.attributes.lastMessageReceivedTimestamp.descending())
      )
      this.replaceQuery(threadQuery)
    })
  }

  onLastCallbackRemoved() {
    if (this._disposable) {
      this._disposable.dispose()
    }
  }
}

export default SendRemindersQuerySubscription

