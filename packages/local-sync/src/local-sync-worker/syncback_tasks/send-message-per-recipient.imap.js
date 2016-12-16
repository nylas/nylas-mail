const {SendmailClient, Errors: {APIError}} = require('isomorphic-core')
const Utils = require('../../shared/utils')
const SyncbackTask = require('./syncback-task')
const MessageFactory = require('../../shared/message-factory')


async function sendPerRecipient({db, imap, baseMessage, usesOpenTracking, usesLinkTracking} = {}) {
  const {Message} = db
  const {account, logger} = imap
  const recipients = baseMessage.getRecipients()
  const failedRecipients = []

  for (const recipient of recipients) {
    const customBody = MessageFactory.buildTrackingBodyForRecipient({
      recipient,
      baseMessage,
      usesOpenTracking,
      usesLinkTracking,
    })

    const individualizedMessage = Utils.copyModel(Message, baseMessage, {
      body: customBody,
    })

    try {
      const sender = new SendmailClient(account, logger);
      await sender.sendCustom(individualizedMessage, {to: [recipient]})
    } catch (error) {
      logger.error(error, {recipient: recipient.email}, 'SendMessagePerRecipient: Failed to send to recipient');
      failedRecipients.push(recipient.email)
    }
  }
  if (failedRecipients.length === recipients.length) {
    throw new APIError('SendMessagePerRecipient: Sending failed for all recipients', 500);
  }
  return {failedRecipients}
}

class SendMessagePerRecipientIMAP extends SyncbackTask {
  description() {
    return `SendMessagePerRecipient`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    if (!imap.account) {
      throw new APIError('SendMessagePerRecipient: Failed, account not available on imap connection')
    }
    const {
      messagePayload,
      usesOpenTracking,
      usesLinkTracking,
    } = this.syncbackRequestObject().props

    const baseMessage = await MessageFactory.buildForSend(db, messagePayload)
    baseMessage.setIsSending(true)

    const sendResult = await sendPerRecipient({db, imap, baseMessage, usesOpenTracking, usesLinkTracking})

    // We strip the tracking links because this is the message that we want to
    // show the user as sent, so it shouldn't contain the tracking links
    baseMessage.body = MessageFactory.stripTrackingLinksFromBody(baseMessage.body)

    // We don't save the message until after successfully sending it.
    // In the next sync loop, the message's labels and other data will be
    // updated, and we can guarantee this because we control message id
    // generation. The thread will be created or updated when we detect this
    // message in the sync loop
    baseMessage.save()

    const {failedRecipients} = sendResult
    return {message: baseMessage.toJSON(), failedRecipients}
  }
}

module.exports = SendMessagePerRecipientIMAP;
