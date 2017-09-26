import MailspringStore from 'mailspring-store';
import SendDraftTask from '../tasks/send-draft-task';
import SyncbackDraftTask from '../tasks/syncback-draft-task';
import TaskQueue from './task-queue';

class OutboxStore extends MailspringStore {
  constructor() {
    super();
    this._tasks = [];
    this.listenTo(TaskQueue, this._populate);
    this._populate();
  }

  _populate() {
    const nextTasks = TaskQueue.queue().filter(
      task => task instanceof SendDraftTask || task instanceof SyncbackDraftTask
    );
    if (this._tasks.length === 0 && nextTasks.length === 0) {
      return;
    }
    this._tasks = nextTasks;
    this.trigger();
  }

  itemsForAccount(accountId) {
    return this._tasks.filter(task => task.draftAccountId === accountId);
  }
}

const store = new OutboxStore();
export default store;
