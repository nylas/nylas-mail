import Task from './task';
import Actions from '../actions';
import BaseDraftTask from './base-draft-task';
import TaskQueue from '../stores/task-queue';
import SendActionsStore from '../stores/send-actions-store';


class PerformSendActionTask extends BaseDraftTask {

  constructor(headerMessageId, sendActionKey) {
    super(headerMessageId)
    this._sendActionKey = sendActionKey
    this._sendTimer = null
    this._taskResolve = () => {}
  }

  label() {
    return "Sending message";
  }

  shouldDequeueOtherTask(otherTask) {
    return (
      otherTask instanceof PerformSendActionTask &&
      this.headerMessageId === otherTask.headerMessageId
    )
  }

  performLocal() {
    if (!this.headerMessageId) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a headerMessageId`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve()
  }

  cancel() {
    const {id: taskId, headerMessageId} = this
    clearTimeout(this._sendTimer)
    Actions.didCancelSendAction({taskId, headerMessageId})
    this._taskResolve(Task.Status.Continue)
  }

  _performSendAction() {
    return this.refreshDraftReference()
    .then((draft) => {
      const sendAction = SendActionsStore.sendActionForKey(this._sendActionKey)
      if (!sendAction) {
        return Promise.reject(new Error(`Cant find send action ${this._sendActionKey} `))
      }
      const {performSendAction} = sendAction
      return performSendAction({draft})
    })
  }
}

export default PerformSendActionTask
