/* eslint global-require: 0 */
import {SendmailClient} from 'isomorphic-core'
import {Actions} from 'nylas-exports'
import LocalDatabaseConnector from '../shared/local-database-connector'
import SendTaskRunner from './send-task-runner'
import {ensureGmailAccessToken} from './sync-utils'

class SendTaskManager {

  async activate() {
    this._unsubscribe = Actions.runSendRequest.listen(this._runSendRequest)
    this._sendTaskRunnersByAccountId = {}
  }

  async deactivate() {
    this._unsubscribe()
  }

  _runSendRequest = async (args) => {
    const {onSuccess, onError, syncbackRequestJSON} = args
    try {
      const task = await this._createTask(syncbackRequestJSON)
      const responseJSON = await this._runTask(task, onSuccess, onError)
      onSuccess(responseJSON)
    } catch (err) {
      onError(err)
    }
  }

  async _createTask(syncbackRequestJSON) {
    const {type, accountId} = syncbackRequestJSON
    const {Account} = await LocalDatabaseConnector.forShared()
    const account = await Account.findById(accountId)

    let Task;
    if (type === 'SendMessage') {
      Task = require('./syncback-tasks/send-message.smtp')
    } else if (type === 'SendMessagePerRecipient') {
      Task = require('./syncback-tasks/send-message-per-recipient.smtp')
    }
    // We don't pass in an actual instance of SyncbackRequest because we don't
    // need any of its data to be persistent across app sessions. Status updates
    // should work as expected within an app session due to object aliasing
    return new Task(account, syncbackRequestJSON)
  }

  async _runTask(task) {
    const {_account: account} = task
    let newCredentials;
    if (account.provider === 'gmail') {
      newCredentials = await ensureGmailAccessToken({account, expiryBufferInSecs: 2 * 60})
    }
    let sendTaskRunner = this._sendTaskRunnersByAccountId[account.id]
    if (newCredentials || !sendTaskRunner) {
      const logger = global.Logger.forAccount(account)
      const db = await LocalDatabaseConnector.forAccount(account.id)
      const smtp = new SendmailClient(account, logger)
      sendTaskRunner = new SendTaskRunner({account, db, smtp, logger})
      this._sendTaskRunnersByAccountId[account.id] = sendTaskRunner
    }
    return sendTaskRunner.runTask(task)
  }

}

export default new SendTaskManager()
