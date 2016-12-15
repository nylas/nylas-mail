const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')
const SendmailClient = require('../../shared/sendmail-client')
const {APIError} = require('../../shared/errors')


// Closes out a multi-send session by marking the sending draft as sent
// and moving it to the user's Sent folder.
class CloseMultiSendSessionIMAP extends SyncbackTask {
  description() {
    return `CloseMultiSendSession`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {Message} = db
    const {messageId} = this.syncbackRequestObject().props
    const {account, logger} = imap
    if (!account) {
      throw new APIError('Send failed: account not available on imap connection')
    }

    const baseMessage = await Message.findMultiSendMessage(messageId);
    const {provider} = account
    const {headerMessageId} = baseMessage
    // Gmail automatically creates sent messages when sending, so we delete each
    // of the ones we sent to each recipient in `SendCustomMessageToIndividual`
    // tasks
    if (provider === 'gmail') {
      try {
        await TaskHelpers.deleteGmailSentMessage({db, imap, provider, headerMessageId})
      } catch (err) {
        // Even if this fails, we need to finish the multi-send session,
        logger.error(err);
      }
    }

    // Regardless of provider, we need to save the actual message we want
    // to show the user as sent
    const sender = new SendmailClient(account, logger);
    const rawMime = await sender.buildMime(baseMessage);
    await TaskHelpers.saveSentMessage({db, imap, provider, rawMime, headerMessageId})

    baseMessage.setIsSent(true)
    await baseMessage.save();
    return baseMessage.toJSON()
  }
}

module.exports = CloseMultiSendSessionIMAP;
