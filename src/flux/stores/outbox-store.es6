import _ from 'underscore';
import NylasStore from 'nylas-store';
import SendDraftTask from '../tasks/send-draft';
import TaskQueueStatusStore from './task-queue-status-store';

class OutboxStore extends NylasStore {

  constructor() {
    super();
    this._tasks = [];
    this.listenTo(TaskQueueStatusStore, this._populate);
    this._populate();
  }

  _populate() {
    const nextTasks = TaskQueueStatusStore.queue().filter((task)=> {
      return task instanceof SendDraftTask;
    });
    if ((this._tasks.length === 0) && (nextTasks.length === 0)) {
      return;
    }
    this._tasks = nextTasks;
    this.trigger();
  }

  itemsForAccount(accountId) {
    return this._tasks.filter((task)=> {
      return task.draft.accountId === accountId;
    });
  }
}
module.exports = new OutboxStore();
