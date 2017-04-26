const {MessageUtils, TrackingUtils} = require('isomorphic-core')
const {SyncbackSMTPTask} = require('../syncback-tasks/syncback-task')

/**
 * This sets up the actual delivery of a message.
 *
 * Errors in this task always mean the message failed to deliver and it's
 * safe to retry
 *
 * We later get EnsureMessageInSentFolder queued to ensure the newly
 * delivered message shows up in the sent folder.
 */
class SendMessageSMTP extends SyncbackSMTPTask {
  description() {
    return `SendMessage`;
  }

  async * _run(db, smtp) {
    const syncbackRequest = this.syncbackRequestObject()
    const {messagePayload} = syncbackRequest.props
    const message = yield MessageUtils.buildForSend(db, messagePayload);
    await smtp.send(message);

    try {
      message.body = TrackingUtils.stripTrackingLinksFromBody(message.body)
      message.setIsSent(true)
      await message.save();
      return {message: message.toJSON()}
    } catch (err) {
      this._logger.error(err, "SendMessage: Failed to save the message to the local sync database after it was successfully delivered")
      return {message: {}}
    }
  }
}

module.exports = SendMessageSMTP;
