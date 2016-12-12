import {
  MailboxPerspective,
} from 'nylas-exports'
import SendRemindersQuerySubscription from './send-reminders-query-subscription'


class SendRemindersMailboxPerspective extends MailboxPerspective {

  constructor(accountIds) {
    super(accountIds)
    this.accountIds = accountIds
    this.name = 'Reminders'
    this.iconName = 'reminders.png'
  }

  get isReminders() {
    return true
  }

  emptyMessage() {
    return "No reminders set"
  }

  threads() {
    return new SendRemindersQuerySubscription(this.accountIds)
  }

  canReceiveThreadsFromAccountIds() {
    return false
  }

  canArchiveThreads() {
    return false
  }

  canTrashThreads() {
    return false
  }

  canMoveThreadsTo() {
    return false
  }

}

export default SendRemindersMailboxPerspective
