import NylasStore from 'nylas-store'
import {Actions} from 'nylas-exports'


class UndoSendStore extends NylasStore {

  constructor() {
    super();
    this._showUndoSend = false
    this._sendActionTaskId = null
  }

  activate() {
    this._unlisteners = [
      Actions.willPerformSendAction.listen(this._onWillPerformSendAction),
      Actions.didPerformSendAction.listen(this._onDidPerformSendAction),
      Actions.didCancelSendAction.listen(this._onDidCancelSendAction),
    ]
  }

  deactivate() {
    this._unlisteners.forEach((unsub) => unsub())
  }

  shouldShowUndoSend() {
    return this._showUndoSend
  }

  sendActionTaskId() {
    return this._sendActionTaskId
  }

  _onWillPerformSendAction = ({taskId}) => {
    this._showUndoSend = true
    this._sendActionTaskId = taskId
    this.trigger()
  }

  _onDidPerformSendAction = () => {
    this._showUndoSend = false
    this._sendActionTaskId = null
    this.trigger()
  }

  _onDidCancelSendAction = () => {
    this._showUndoSend = false
    this._sendActionTaskId = null
    this.trigger()
  }
}

export default new UndoSendStore()

