import {ExponentialBackoffScheduler} from 'isomorphic-core'
import {Actions} from 'nylas-exports'
import {runWithRetryLogic} from './sync-utils'

export default class SendTaskRunner {
  constructor({account, db, smtp, logger}) {
    this._account = account
    this._db = db
    this._smtp = smtp
    this._logger = logger
  }

  runTask = async (task) => {
    const before = new Date();
    // syncbackRequests for send tasks aren't persistent database instances
    const syncbackRequestJSON = task.syncbackRequestObject();
    this._logger.log(`🔃 📤 ${task.description()}`, syncbackRequestJSON.props)

    const run = async () => {
      syncbackRequestJSON.status = task.inProgressStatusType();
      const responseJSON = await task.run(this._db, this._smtp)
      syncbackRequestJSON.status = "SUCCEEDED";
      const after = new Date();
      this._logger.log(`🔃 📤 ${task.description()} Succeeded (${after.getTime() - before.getTime()}ms)`)
      return responseJSON
    }

    const onRetryableError = (error, delay) => {
      const after = new Date();
      Actions.recordUserEvent('Retrying syncback task', {
        accountId: this._account.id,
        provider: this._account.provider,
        errorMessage: error.message,
      })
      syncbackRequestJSON.status = "NEW";
      this._logger.warn(`🔃 📤 ${task.description()} Failed with retryable error, retrying in ${delay}ms (This run took ${after.getTime() - before.getTime()}ms)`, {syncbackRequest: syncbackRequestJSON, error})
    }

    const retryScheduler = new ExponentialBackoffScheduler({
      baseDelay: 1000,
      maxDelay: 2 * 60 * 1000,
    })

    try {
      const responseJSON = await runWithRetryLogic({run, onRetryableError, retryScheduler})
      return responseJSON
    } catch (error) {
      const after = new Date();
      const fingerprint = ["{{ default }}", "syncback task", error.message];
      NylasEnv.reportError(error, {fingerprint: fingerprint});
      syncbackRequestJSON.error = error;
      syncbackRequestJSON.status = "FAILED";
      this._logger.error(`🔃 📤 ${task.description()} Failed (${after.getTime() - before.getTime()}ms)`, {syncbackRequest: syncbackRequestJSON, error})
      throw error
    }
  }
}
