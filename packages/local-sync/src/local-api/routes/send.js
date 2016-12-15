const Joi = require('joi');
const Utils = require('../../shared/utils');
const SendmailClient = require('../../shared/sendmail-client');
const MessageFactory = require('../../shared/message-factory');
const {HTTPError} = require('../../shared/errors');
const LocalDatabaseConnector = require('../../shared/local-database-connector');


const SEND_TIMEOUT_MS = 1000 * 60; // millliseconds

const recipient = Joi.object().keys({
  name: Joi.string().required(),
  email: Joi.string().email().required(),
  // Rest are optional
  account_id: Joi.string(),
  client_id: Joi.string(),
  id: Joi.string(),
  thirdPartyData: Joi.object(),
  server_id: Joi.string(),
  object: Joi.string(),
});

const recipientList = Joi.array().items(recipient);

const replyWithError = (request, reply, error) => {
  if (!error.httpCode) {
    error.type = 'ApiError';
    error.httpCode = 500;
  }
  request.logger.error('Replying with error', error, error.logContext);
  reply(JSON.stringify(error)).code(error.httpCode);
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/send',
    config: {
      validate: {
        payload: {
          to: recipientList,
          cc: recipientList,
          bcc: recipientList,
          from: recipientList.length(1).required(),
          reply_to: recipientList.min(0).max(1),
          subject: Joi.string().required(),
          body: Joi.string().required(),
          thread_id: Joi.string(),
          reply_to_message_id: Joi.string(),
          client_id: Joi.string().required(),
          account_id: Joi.string(),
          id: Joi.string(),
          object: Joi.string().equal('draft'),
          metadata: Joi.array().items(Joi.object()),
          date: Joi.number(),
          files: Joi.array().items(Joi.string()),
          file_ids: Joi.array(),
          uploads: Joi.array(),
          events: Joi.array(),
          pristine: Joi.boolean(),
          categories: Joi.array().items(Joi.string()),
          draft: Joi.boolean(),
        },
      },
    },
    async handler(request, reply) {
      // TODO make this a task to trigger a sync loop run
      try {
        const account = request.auth.credentials;
        const db = await LocalDatabaseConnector.forAccount(account.id)
        const message = await MessageFactory.buildForSend(db, request.payload)
        const sender = new SendmailClient(account, request.logger);
        await sender.send(message);

        // We don't save the message until after successfully sending it.
        // In the next sync loop, the message's labels and other data will be
        // updated, and we can guarantee this because we control message id
        // generation.
        // The thread will be created or updated when we detect this
        // message in the sync loop
        message.setIsSent(true)
        await message.save();
        // TODO save to sent folder if non-gmail
        reply(message.toJSON());
      } catch (err) {
        replyWithError(request, reply, err);
      }
    },
  });

  // Initiates a multi-send session by creating a new multi-send draft.
  server.route({
    method: 'POST',
    path: '/send-multiple',
    config: {
      validate: {
        payload: {
          to: recipientList,
          cc: recipientList,
          bcc: recipientList,
          from: recipientList.length(1).required(),
          reply_to: recipientList.min(0).max(1),
          subject: Joi.string().required(),
          body: Joi.string().required(),
          thread_id: Joi.string(),
          reply_to_message_id: Joi.string(),
          client_id: Joi.string().required(),
          account_id: Joi.string(),
          id: Joi.string(),
          object: Joi.string().equal('draft'),
          metadata: Joi.array().items(Joi.object()),
          date: Joi.number(),
          files: Joi.array().items(Joi.string()),
          file_ids: Joi.array(),
          uploads: Joi.array(),
          events: Joi.array(),
          pristine: Joi.boolean(),
          categories: Joi.array().items(Joi.string()),
          draft: Joi.boolean(),
        },
      },
    },
    async handler(request, reply) {
      try {
        const accountId = request.auth.credentials.id;
        const db = await LocalDatabaseConnector.forAccount(accountId)
        const message = await MessageFactory.buildForSend(db,
          Object.assign(request.payload, {draft: false})
        )
        message.setIsSending(true)
        await message.save();
        reply(message.toJSON());
      } catch (err) {
        replyWithError(request, reply, err);
      }
    },
  });

  // Performs a single send operation in an individualized multi-send
  // session. Sends a copy of the draft at draft_id to the specified address
  // with the specified body, and ensures that a corresponding sent message is
  // either not created in the user's Sent folder or is immediately
  // deleted from it.
  server.route({
    method: 'POST',
    path: '/send-multiple/{messageId}',
    config: {
      validate: {
        params: {
          messageId: Joi.string(),
        },
        payload: {
          send_to: recipient.required(),
          body: Joi.string().required(),
        },
      },
    },
    async handler(request, reply) {
      try {
        const requestStarted = Date.now()
        const account = request.auth.credentials;
        const {messageId} = request.params;
        const sendTo = request.payload.send_to;

        if (!Utils.isValidId(messageId)) {
          throw new HTTPError(`messageId is not a base-36 integer`, 400)
        }

        const db = await LocalDatabaseConnector.forAccount(account.id)
        const {Message} = db
        const baseMessage = await Message.findMultiSendMessage(messageId)
        if (!baseMessage.getRecipients().find(contact => contact.email === sendTo.email)) {
          throw new HTTPError(
            "Invalid sendTo, not present in message recipients",
            400
          );
        }

        if (Date.now() - requestStarted > SEND_TIMEOUT_MS) {
          // Preemptively time out the request if we got stuck doing database work
          // -- we don't want clients to disconnect and then still send the
          // message.
          reply('Request timed out.').code(504);
        }
        const customMessage = Utils.copyModel(Message, baseMessage, {
          body: MessageFactory.replaceBodyMessageIds(baseMessage.id, request.payload.body),
        })
        const sender = new SendmailClient(account, request.logger);
        const response = await sender.sendCustom(customMessage, {to: [sendTo]})
        reply(response);
      } catch (err) {
        replyWithError(request, reply, err);
      }
    },
  });

  // Closes out a multi-send session by marking the sending draft as sent
  // and moving it to the user's Sent folder.
  server.route({
    method: 'DELETE',
    path: '/send-multiple/{messageId}',
    config: {
      validate: {
        params: {
          messageId: Joi.string(),
        },
      },
    },
    async handler(request, reply) {
      try {
        const account = request.auth.credentials;
        const {messageId} = request.params;

        if (!Utils.isValidId(messageId)) {
          throw new HTTPError(`messageId is not a base-36 integer`, 400)
        }

        const db = await LocalDatabaseConnector.forAccount(account.id);
        const {Message} = db
        const baseMessage = await Message.findMultiSendMessage(messageId);

        // gmail creates sent messages for each one, go through and delete them
        if (account.provider === 'gmail') {
          try {
            await db.SyncbackRequest.create({
              accountId: account.id,
              type: "DeleteSentMessage",
              props: { headerMessageId: baseMessage.headerMessageId },
            });
          } catch (err) {
            // Even if this fails, we need to finish the multi-send session,
            request.logger.error(err, err.logContext);
          }
        }

        const sender = new SendmailClient(account, request.logger);
        const rawMime = await sender.buildMime(baseMessage);

        await db.SyncbackRequest.create({
          accountId: account.id,
          type: "SaveSentMessage",
          props: {rawMime, headerMessageId: baseMessage.headerMessageId},
        });

        baseMessage.setIsSent(true)
        await baseMessage.save();
        reply(baseMessage.toJSON());
      } catch (err) {
        replyWithError(request, reply, err);
      }
    },
  });
};
