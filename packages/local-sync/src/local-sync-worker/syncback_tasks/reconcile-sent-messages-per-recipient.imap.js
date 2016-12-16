const {SendmailClient, Errors: {APIError}} = require('isomorphic-core')
const TaskHelpers = require('./task-helpers')
const SyncbackTask = require('./syncback-task')


// Closes out a multi-send session by marking the sending draft as sent
// and moving it to the user's Sent folder.
class ReconcileSentMessagesPerRecipientIMAP extends SyncbackTask {
  description() {
    return `ReconcileSentMessagesPerRecipient`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {Message} = db
    const {messageId} = this.syncbackRequestObject().props
    const {account, logger} = imap
    if (!account) {
      throw new APIError('ReconcileSentMessagesPerRecipient: Failed, account not available on imap connection')
    }

    const baseMessage = await Message.findMultiSendMessage(db, messageId);
    const {provider} = account
    const {headerMessageId} = baseMessage

    // Gmail automatically creates sent messages when sending, so we delete each
    // of the ones we sent to each recipient in the `SendMessagePerRecipient`
    // task
    if (provider === 'gmail') {
      try {
        await TaskHelpers.deleteGmailSentMessage({db, imap, provider, headerMessageId})
      } catch (err) {
        // Even if this fails, we need to finish attempting to save the
        // baseMessage to the sent folder
        logger.error(err, 'ReconcileSentMessagesPerRecipient: Failed to delete Gmail sent messages');
      }
    }

    // Regardless of provider, we need to save the actual message we want
    // the user to see as sent
    const sender = new SendmailClient(account, logger);
    const rawMime = await sender.buildMime(baseMessage);
    await TaskHelpers.saveSentMessage({db, imap, provider, rawMime, headerMessageId})

    baseMessage.setIsSent(true)
    await baseMessage.save();
    return baseMessage.toJSON()
  }
}

module.exports = ReconcileSentMessagesPerRecipientIMAP;
