import Task from './task';
import Actions from '../actions';
import BaseDraftTask from './base-draft-task';
import TaskQueue from '../stores/task-queue';
import SendActionsStore from '../stores/send-actions-store';


class PerformSendActionTask extends BaseDraftTask {

  constructor(draftClientId, sendActionKey) {
    super(draftClientId)
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
      this.draftClientId === otherTask.draftClientId
    )
  }

  performLocal() {
    if (!this.draftClientId) {
      const errMsg = `Attempt to call ${this.constructor.name}.performLocal without a draftClientId`;
      return Promise.reject(new Error(errMsg));
    }
    return Promise.resolve()
  }

  performRemote() {
    const sameTasks = TaskQueue.findTasks(PerformSendActionTask, {draftClientId: this.draftClientId})
    if (sameTasks.length > 1) {
      return Promise.resolve(Task.Status.Continue)
    }
    const undoSendTimeout = NylasEnv.config.get('core.sending.undoSend')
    if (!undoSendTimeout) {
      return this._performSendAction()
      .then(() => Task.Status.Success)
      .catch((err) => [Task.Status.Failed, err])
    }

    return new Promise((resolve, reject) => {
      const {id: taskId, draftClientId} = this
      this._taskResolve = resolve

      Actions.willPerformSendAction({taskId, draftClientId})
      this._sendTimer = setTimeout(() => {
        this._performSendAction()
        .then(() => resolve(Task.Status.Success))
        .catch((err) => reject([Task.Status.Failed, err]))
        .finally(() => Actions.didPerformSendAction({taskId, draftClientId}))
      }, undoSendTimeout)
    })
  }

  cancel() {
    const {id: taskId, draftClientId} = this
    clearTimeout(this._sendTimer)
    Actions.didCancelSendAction({taskId, draftClientId})
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
