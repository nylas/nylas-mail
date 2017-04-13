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

  inProgressStatusType() {
    return 'INPROGRESS-RETRYABLE'
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

  async run(db, imapOrSmtp, ctx = {}) {
    const {timeoutDelay = TIMEOUT_DELAY} = ctx
    const timeout = setTimeout(this.stop, timeoutDelay)
    const startTime = Date.now()
    const response = await this._interruptible.run(() => this._run(db, imapOrSmtp, ctx))

    // Since we've already completed the task, we don't want to fail before
    // we return the response. Wrap everything else in a try/catch and still
    // return the response if an error is thrown.
    try {
      Actions.recordPerfMetric({
        action: 'syncback-task-run',
        accountId: this._account.id,
        actionTimeMs: Date.now() - startTime,
        maxValue: 10 * 60 * 1000,
        type: this._syncbackRequest.type,
        provider: this._account.provider,
      })
      clearTimeout(timeout)
    } catch (err) {
      // Don't throw
    }
    return response
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

  inProgressStatusType() {
    return 'INPROGRESS-NOTRETRYABLE'
  }
}

export default SyncbackTask
