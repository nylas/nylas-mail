const MessageFactory = require('../shared/message-factory')


class HTTPError extends Error {
  constructor(message, httpCode, logContext) {
    super(message);
    this.httpCode = httpCode;
    this.logContext = logContext;
  }
}

module.exports = {
  HTTPError,
  setReplyHeaders: (newMessage, prevMessage) => {
    if (prevMessage.messageIdHeader) {
      newMessage.inReplyTo = prevMessage.headerMessageId;
      if (prevMessage.references) {
        newMessage.references = prevMessage.references.concat(prevMessage.headerMessageId);
      } else {
        newMessage.references = [prevMessage.messageIdHeader];
      }
    }
  },
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
      throw new HTTPError(`Couldn't find multi-send draft ${draftId}`, 400);
    }
    if (draft.isSent || !draft.isSending) {
      throw new HTTPError(`Message ${draftId} is not a multi-send draft`, 400);
    }
    return draft;
  },
  validateRecipientsPresent: (draft) => {
    const {to, cc, bcc} = draft;
    const recipients = [].concat(to, cc, bcc);
    if (recipients.length === 0) {
      throw new HTTPError("No recipients specified", 400);
    }
  },
  validateBase36: (value, name) => {
    if (value == null) { return; }
    if (isNaN(parseInt(value, 36))) {
      throw new HTTPError(`${name} is not a base-36 integer`, 400)
    }
  },
}
