const {SendmailClient} = require('isomorphic-core')
const SyncbackTask = require('../syncback-tasks/syncback-task')
const MessageFactory = require('../../shared/message-factory')

/**
 * This sets up the actual delivery of a message.
 *
 * Errors in this task always mean the message failed to deliver and it's
 * safe to retry
 *
 * We later get EnsureMessageInSentFolder queued to ensure the newly
 * delivered message shows up in the sent folder.
 */
class SendMessageSMTP extends SyncbackTask {
  description() {
    return `SendMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db) {
    const {messagePayload} = this.syncbackRequestObject().props

    const message = await MessageFactory.buildForSend(db, messagePayload);
    const logger = global.Logger.forAccount(this._account);
    const sender = new SendmailClient(this._account, logger);
    await sender.send(message);

    try {
      message.setIsSent(true)
      await message.save();
      return {message: message.toJSON()}
    } catch (err) {
      logger.error(err, "SendMessage: Failed to save the message to the local sync database after it was successfully delivered")
      return {message: {}}
    }
  }
}

module.exports = SendMessageSMTP;
