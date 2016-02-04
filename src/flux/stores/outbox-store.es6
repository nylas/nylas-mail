import _ from 'underscore';
import NylasStore from 'nylas-store';
import SendDraftTask from '../tasks/send-draft';
import TaskQueueStatusStore from './task-queue-status-store';

class OutboxStore extends NylasStore {

  constructor() {
    super();
    this.listenTo(TaskQueueStatusStore, this._populate);
    this._populate();
  }

  _populate() {
    this._tasks = TaskQueueStatusStore.queue().filter((task)=> {
      return task instanceof SendDraftTask;
    });
    this.trigger();
  }

  itemsForAccount(accountId) {
    return this._tasks.filter((task)=> {
      return task.draft.accountId === accountId;
    });
  }
}
module.exports = new OutboxStore();
