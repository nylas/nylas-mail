const {Errors: {APIError}, MessageUtils, TrackingUtils, ModelUtils} = require('isomorphic-core')
const {SyncbackSMTPTask} = require('./syncback-task')


/**
 * This enables customized link and open tracking on a per-recipient basis
 * by delivering several messages to each recipient.
 *
 * Errors in this task always mean all message failed to send to all
 * receipients.
 *
 * If it failed to some recipients, we return a `failedRecipients` array
 * to notify the user.
 *
 * We later get EnsureMessageInSentFolder queued with the
 * `customSentMessage` flag set to ensure the newly delivered message shows
 * up in the sent folder and only a single message shows up in the sent
 * folder.
 */
class SendMessagePerRecipientSMTP extends SyncbackSMTPTask {
  description() {
    return `SendMessagePerRecipient`;
  }

  async * _run(db, smtp) {
    const syncbackRequest = this.syncbackRequestObject()
    const {
      messagePayload,
      usesOpenTracking,
      usesLinkTracking,
    } = syncbackRequest.props;
    const baseMessage = yield MessageUtils.buildForSend(db, messagePayload)

    let sendResult;
    try {
      sendResult = yield this._sendPerRecipient({
        smtp, baseMessage, logger: this._logger, usesOpenTracking, usesLinkTracking,
      })
    } catch (err) {
      throw new APIError('SendMessagePerRecipient: Sending failed for all recipients', 500);
    }
    /**
     * Once messages have actually been delivered, we need to be very
     * careful not to throw an error from this task. An Error in the send
     * task implies failed delivery and the prompting of users to try
     * again.
     */
    try {
      /**
       * When we send to multiple recipients, we only want 1 message in
       * our sent folder that is void of tracking links.
       *
       * If the send is quick, we'll beat the sync loop and save a new
       * message to the database. If the send is slow, on Gmail there may
       * already be a message in our sent folder that was synced there.
       */
      let sentMessage = await db.Message.findById(baseMessage.id, {
        include: [{model: db.Folder}, {model: db.Label}, {model: db.File}],
      });
      if (!sentMessage) {
        sentMessage = baseMessage;
      }

      // We strip the tracking links because this is the message that we want to
      // show the user as sent, so it shouldn't contain the tracking links
      sentMessage.body = TrackingUtils.stripTrackingLinksFromBody(baseMessage.body)
      sentMessage.setIsSent(true)

      // We don't save the message until after successfully sending it.
      // In the next sync loop, the message's labels and other data will
      // be updated, and we can guarantee this because we control message
      // id generation. The thread will be created or updated when we
      // detect this message in the sync loop
      await sentMessage.save()

      return {
        message: sentMessage.toJSON(),
        failedRecipients: sendResult.failedRecipients,
      }
    } catch (err) {
      this._logger.error('SendMessagePerRecipient: Failed to save the baseMessage to local sync database after it was successfully delivered', err);
      return {message: {}, failedRecipients: []}
    }
  }

  async _sendPerRecipient({smtp, baseMessage, usesOpenTracking, usesLinkTracking} = {}) {
    const recipients = baseMessage.getRecipients()
    const failedRecipients = []

    await Promise.all(recipients.map(async recipient => {
      const customBody = TrackingUtils.addRecipientToTrackingLinks({
        recipient,
        baseMessage,
        usesOpenTracking,
        usesLinkTracking,
      })

      const individualizedMessageValues = ModelUtils.copyModelValues(baseMessage, {
        body: customBody,
      })
      // TODO we set these temporary properties which aren't stored in the
      // database model because SendmailClient requires them to send the message
      // with the correct headers.
      // This should be cleaned up
      individualizedMessageValues.references = baseMessage.references;
      individualizedMessageValues.inReplyTo = baseMessage.inReplyTo;

      try {
        await smtp.sendCustom(individualizedMessageValues, {to: [recipient]})
      } catch (error) {
        this._logger.error(error, {recipient: recipient.email}, 'SendMessagePerRecipient: Failed to send to recipient');
        failedRecipients.push(recipient.email)
      }
    }))
    if (failedRecipients.length === recipients.length) {
      throw new APIError('SendMessagePerRecipient: Sending failed for all recipients', 500);
    }
    return {failedRecipients}
  }
}

module.exports = SendMessagePerRecipientSMTP;
