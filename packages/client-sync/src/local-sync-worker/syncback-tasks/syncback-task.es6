import {Actions} from 'nylas-exports'
import Interruptible from '../../shared/interruptible'

// TODO: Choose a more appropriate timeout once we've gathered some metrics
const TIMEOUT_DELAY = 5 * 60 * 1000;

class SyncbackTask {
  constructor(account, syncbackRequest) {
    this._account = account;
    this._syncbackRequest = syncbackRequest;
    this._interruptible = new Interruptible()
    if (!this._account) {
      throw new Error("SyncbackTask requires an account")
    }
    if (!this._syncbackRequest) {
      throw new Error("SyncbackTask requires a syncbackRequest")
    }
    this._logger = global.Logger.forAccount(this._account)
  }

  syncbackRequestObject() {
    return this._syncbackRequest;
  }

  description() {
    throw new Error("Must return a description")
  }

  resource() {
    throw new Error("Must return a resource. Must be one of ['imap', 'smtp']")
  }

  affectsImapMessageUIDs() {
    throw new Error("Must implement `affectsImapMessageUIDs`")
  }

  stop = () => {
    // If we can't retry the task, we don't want to interrupt it.
    if (this._syncbackRequest.status !== "INPROGRESS-NOTRETRYABLE") {
      this._interruptible.interrupt({forceReject: true})
      Actions.recordUserEvent("SyncbackTask Stopped", {
        accountId: this._account.id,
        type: this._syncbackRequest.type,
      })
    }
  }

  async * _run() { // eslint-disable-line
    throw new Error("Must implement a _run method")
  }

  async run({timeoutDelay = TIMEOUT_DELAY} = {}) {
    const timeout = setTimeout(this.stop, timeoutDelay)
    const startTime = Date.now()
    await this._interruptible.run(this._run)
    Actions.recordPerfMetric({
      action: 'syncback-task-run',
      accountId: this._account.id,
      actionTimeMs: Date.now() - startTime,
      maxValue: 10 * 60 * 1000,
      type: this._syncbackRequest.type,
    })
    clearTimeout(timeout)
  }
}

export class SyncbackIMAPTask extends SyncbackTask {
  resource() {
    return 'imap'
  }
}

export class SyncbackSMTPTask extends SyncbackTask {
  resource() {
    return 'smtp'
  }
}

export default SyncbackTask
