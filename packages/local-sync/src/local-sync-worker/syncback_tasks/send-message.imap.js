const {SendmailClient, Errors: {APIError}} = require('isomorphic-core')
const SyncbackTask = require('./syncback-task')
const TaskHelpers = require('./task-helpers')
const MessageFactory = require('../../shared/message-factory')


class SendMessageIMAP extends SyncbackTask {
  description() {
    return `SendMessage`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {messagePayload} = this.syncbackRequestObject().props
    const {account, logger} = imap
    if (!account) {
      throw new APIError('Send failed: account not available on imap connection')
    }

    const message = await MessageFactory.buildForSend(db, messagePayload)
    const sender = new SendmailClient(account, logger);
    await sender.send(message);

    // We don't save the message until after successfully sending it.
    // In the next sync loop, the message's labels and other data will be
    // updated, and we can guarantee this because we control message id
    // generation. The thread will be created or updated when we detect this
    // message in the sync loop
    message.setIsSent(true)
    await message.save();

    try {
      const {provider} = account
      if (provider !== 'gmail') {
        // Gmail will automatically create the sent message in the sent folder
        // because of it's robust integration of IMAP/SMTP. Otherwise, we need to
        // create it ourselves
        const rawMime = await sender.buildMime(message);
        const {headerMessageId} = message
        await TaskHelpers.saveSentMessage({db, imap, provider, rawMime, headerMessageId})
      }
    } catch (err) {
      // If we encounter an error trying to save the send message, log it and
      // proceed. We don't want N1 to think that the message did not send if it
      // actually did
      logger.error(err, 'SendMessage: Could not sent message to sent folder')
    }
    return message.toJSON()
  }
}

module.exports = SendMessageIMAP;
