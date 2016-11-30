const _ = require('underscore');

const setReplyHeaders = (newMessage, prevMessage) => {
  if (prevMessage.messageIdHeader) {
    newMessage.inReplyTo = prevMessage.headerMessageId;
    if (prevMessage.references) {
      newMessage.references = prevMessage.references.concat(prevMessage.headerMessageId);
    } else {
      newMessage.references = [prevMessage.messageIdHeader];
    }
  }
}

class HTTPError extends Error {
  constructor(message, httpCode, logContext) {
    super(message);
    this.httpCode = httpCode;
    this.logContext = logContext;
  }
}

module.exports = {
  HTTPError,
  findOrCreateMessageFromJSON: async (data, db, isDraft) => {
    const {Thread, Message} = db;

    const existingMessage = await Message.findById(data.id);
    if (existingMessage) {
      return existingMessage;
    }

    const {to, cc, bcc, from, replyTo, subject, body, account_id, date, id} = data;

    const message = Message.build({
      accountId: account_id,
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      replyTo: replyTo,
      subject: subject,
      body: body,
      unread: true,
      isDraft: isDraft,
      isSent: false,
      version: 0,
      date: date,
      id: id,
    });

    // TODO
    // Attach files
    // Update our contact list
    // Add events
    // Add metadata??

    let replyToThread;
    let replyToMessage;
    if (data.thread_id != null) {
      replyToThread = await Thread.find({
        where: {id: data.thread_id},
        include: [{
          model: Message,
          as: 'messages',
          attributes: _.without(Object.keys(Message.attributes), 'body'),
        }],
      });
    }
    if (data.reply_to_message_id != null) {
      replyToMessage = await Message.findById(data.reply_to_message_id);
    }

    if (replyToThread && replyToMessage) {
      if (!replyToThread.messages.find((msg) => msg.id === replyToMessage.id)) {
        throw new HTTPError(
          `Message ${replyToMessage.id} is not in thread ${replyToThread.id}`,
          400
        )
      }
    }

    let thread;
    if (replyToMessage) {
      setReplyHeaders(message, replyToMessage);
      thread = await message.getThread();
    } else if (replyToThread) {
      thread = replyToThread;
      const previousMessages = thread.messages.filter(msg => !msg.isDraft);
      if (previousMessages.length > 0) {
        const lastMessage = previousMessages[previousMessages.length - 1]
        setReplyHeaders(message, lastMessage);
      }
    } else {
      thread = Thread.build({
        accountId: account_id,
        subject: message.subject,
        firstMessageDate: message.date,
        lastMessageDate: message.date,
        lastMessageSentDate: message.date,
      })
    }

    const savedMessage = await message.save();
    const savedThread = await thread.save();
    await savedThread.addMessage(savedMessage);

    return savedMessage;
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
