const MessageFactory = require('../shared/message-factory')
const Errors = require('../shared/errors')


module.exports = {
  findOrCreateMessageFromJSON: async (data, db) => {
    const {Message} = db;

    const existingMessage = await Message.findById(data.id);
    if (existingMessage) {
      return existingMessage;
    }

    return MessageFactory.associateFromJSON(data, db)
  },
  findMultiSendDraft: async (draftId, db) => {
    const draft = await db.Message.findById(draftId)
    if (!draft) {
      throw new Errors.HTTPError(`Couldn't find multi-send draft ${draftId}`, 400);
    }
    if (draft.isSent || !draft.isSending) {
      throw new Errors.HTTPError(`Message ${draftId} is not a multi-send draft`, 400);
    }
    return draft;
  },
  validateRecipientsPresent: (draft) => {
    const {to, cc, bcc} = draft;
    const recipients = [].concat(to, cc, bcc);
    if (recipients.length === 0) {
      throw new Errors.HTTPError("No recipients specified", 400);
    }
  },
  validateBase36: (value, name) => {
    if (value == null) { return; }
    if (isNaN(parseInt(value, 36))) {
      throw new Errors.HTTPError(`${name} is not a base-36 integer`, 400)
    }
  },
}
