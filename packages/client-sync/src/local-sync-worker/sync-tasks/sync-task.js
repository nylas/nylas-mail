const MessageProcessor = require('../../message-processor')
const Interruptible = require('../../shared/interruptible')

/**
 * SyncTask represents an operation run by the SyncWorker.
 * Any IMAP sync operation that runs during sync should extend from this class
 * and implement `runTask`
 *
 * By default, this class ensures that we skip the operation if the message
 * processing queue is full, and ensures that the operation is interruptible by
 * extending from Interruptible.
 */
class SyncTask extends Interruptible {

  constructor({account} = {}) {
    super()
    this._account = account
    if (!this._account) {
      throw new Error("SyncTask requires an account")
    }
    this._logger = global.Logger.forAccount(this._account)
  }

  description() {
    throw new Error("Must return a description")
  }

  /**
   * @returns a Promise that resolves when the operation has been executed to
   * completion or interrupted. Rejects if an error is thrown.
   */
  async run(...args) {
    if (MessageProcessor.queueIsFull()) {
      this._logger.log(`🔃  Skipping sync operation - Message processing queue is full`)
      return Promise.resolve()
    }
    return super.run(this.runTask, this, ...args)
  }

  /**
   * Any class that extends from `SyncTask` must implement `runTask`
   * as a generator function, meaning that it returns a
   * generator object.
   * (https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/function*)
   *
   * This will allow it to be interrupted in between async operations. In order
   * to indicate where the function can be interrupted, you must use the
   * keyword `yield` instead of `await` to wait for the resolution of Promises.
   *
   * e.g.
   * ```
   * class MyTask extends SyncTask {
   *
   *   async * runTask(db, imap) {
   *     // Use `yield` to indicate that we can interrupt the function after
   *     // this async operation has resolved
   *     const models = yield db.Messages.findAll()
   *
   *     // If the operation is interrupted, code execution will stop here!
   *
   *     // ...
   *
   *     await saveModels(models)
   *     // `await` wont stop code execution even if operation is interrupted
   *
   *     // ...
   *   }
   * }
   * ```
   */
  * runTask(db, imap) { // eslint-disable-line
    throw new Error('Must implement `SyncTask::runTask`')
  }
}

module.exports = SyncTask
