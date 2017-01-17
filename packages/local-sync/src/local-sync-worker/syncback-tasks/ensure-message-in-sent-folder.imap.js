const {SendmailClient, Provider, Errors: {APIError}} = require('isomorphic-core')
const IMAPHelpers = require('../imap-helpers')
const SyncbackTask = require('./syncback-task')
const {getReplyHeaders} = require('../../shared/message-factory')

/**
 * Ensures that sent messages show up in the sent folder.
 *
 * Gmail does this automatically. IMAP needs to do this manually.
 *
 * If we've `sentPerRecipient` that means we've actually sent many
 * messages (on per recipient). Gmail will have automatically created tons
 * of messages in the sent folder. We need to make it look like you only
 * sent 1 message. To do this we, delete all of the messages Gmail
 * automatically created (keyed by the same Meassage-Id header we set),
 * then stuff a copy of the original message in the sent folder.
 */
class EnsureMessageInSentFolderIMAP extends SyncbackTask {
  description() {
    return `EnsureMessageInSentFolder`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {Message, Reference} = db
    const {messageId, sentPerRecipient} = this.syncbackRequestObject().props
    const {account, logger} = imap
    if (!account) {
      throw new APIError('EnsureMessageInSentFolder: Failed, account not available on imap connection')
    }

    const baseMessage = await Message.findById(messageId,
      {include: [{model: db.Folder}, {model: db.Label}, {model: db.File}]});

    if (!baseMessage) {
      throw new APIError(`Couldn't find message ${messageId} to stuff in sent folder`, 500)
    }

    // Since we store References in a separate table for indexing and don't
    // create these objects until the sent message is picked up via the
    // account's sync (since that's when we create the Thread object and the
    // references must be linked to the thread), we have to reconstruct the
    // threading headers here before saving the message to the Sent folder.
    const replyToMessage = await Message.findById(
      baseMessage.inReplyToLocalMessageId,
      { include: [{model: Reference, as: 'references', attributes: ['id', 'rfc2822MessageId']}] });
    if (replyToMessage) {
      const {inReplyTo, references} = getReplyHeaders(replyToMessage);
      baseMessage.inReplyTo = inReplyTo;
      baseMessage.references = references;
    }

    const {provider} = account
    const {headerMessageId} = baseMessage

    // Gmail automatically creates sent messages when sending, so we
    // delete each of the ones we sent to each recipient in the
    // `SendMessagePerRecipient` task
    //
    // Each participant gets a message, but all of those messages have the
    // same Message-ID header in them. This allows us to find all of the
    // sent messages and clean them up
    if (sentPerRecipient && provider === Provider.Gmail) {
      try {
        await IMAPHelpers.deleteGmailSentMessages({db, imap, provider, headerMessageId})
      } catch (err) {
        // Even if this fails, we need to finish attempting to save the
        // baseMessage to the sent folder
        logger.error(err, 'EnsureMessageInSentFolder: Failed to delete Gmail sent messages');
      }
    }

    /**
     * If we've sentPerRecipient that means we need to always re-add the
     * sent base message.
     *
     * Only gmail optimistically creates a sent message for us. We need to
     * to it manually for all other providers
     */
    if (provider !== 'gmail' || sentPerRecipient) {
      const sender = new SendmailClient(account, logger);
      const rawMime = await sender.buildMime(baseMessage);
      await IMAPHelpers.saveSentMessage({db, imap, provider, rawMime, headerMessageId})
    }

    return baseMessage.toJSON()
  }
}

module.exports = EnsureMessageInSentFolderIMAP;
