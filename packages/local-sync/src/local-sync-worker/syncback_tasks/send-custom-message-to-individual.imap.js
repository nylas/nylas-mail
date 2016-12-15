const {SendmailClient, Errors: {APIError}} = require('isomorphic-core')
const SyncbackTask = require('./syncback-task')
const Utils = require('../../shared/message-factory')
const MessageFactory = require('../../shared/message-factory')


class SendCustomMessageToIndividualIMAP extends SyncbackTask {
  description() {
    return `SendCustomMessageToIndividual`;
  }

  affectsImapMessageUIDs() {
    return false
  }

  async run(db, imap) {
    const {Message} = db
    const {messageId, sendTo, customBody} = this.syncbackRequestObject().props
    const {account, logger} = imap
    if (!account) {
      throw new APIError('Send failed: account not available on imap connection')
    }

    const baseMessage = await Message.findMultiSendMessage(messageId)
    if (!baseMessage.getRecipients().find(contact => contact.email === sendTo.email)) {
      throw new APIError(`Invalid send_to, not present in message recipients`, 400);
    }

    const individualizedMessage = Utils.copyModel(Message, baseMessage, {
      body: MessageFactory.replaceBodyMessageIds(baseMessage.id, customBody),
    })
    const sender = new SendmailClient(account, logger);
    await sender.sendCustom(individualizedMessage, {to: [sendTo]})
    return individualizedMessage.toJSON();
  }
}

module.exports = SendCustomMessageToIndividualIMAP;
