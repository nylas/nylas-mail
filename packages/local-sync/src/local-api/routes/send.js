const Joi = require('joi');
const LocalDatabaseConnector = require('../../shared/local-database-connector');
const SendingUtils = require('../sending-utils');
const SendmailClient = require('../sendmail-client');

const SEND_TIMEOUT = 1000 * 60; // millliseconds

const recipient = Joi.object().keys({
  name: Joi.string().required(),
  email: Joi.string().email().required(),
  account_id: Joi.string(),
  client_id: Joi.string(),
  id: Joi.string(),
  thirdPartyData: Joi.object(),
});
const recipientList = Joi.array().items(recipient);

const respondWithError = (request, reply, error) => {
  if (!error.httpCode) {
    error.type = 'apiError';
    error.httpCode = 500;
  }
  request.logger.error('responding with error', error, error.logContext);
  reply(JSON.stringify(error)).code(error.httpCode);
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/send',
    handler: async (request, reply) => {
      try {
        const account = request.auth.credentials;
        const db = await LocalDatabaseConnector.forAccount(account.id)
        const draft = await SendingUtils.findOrCreateMessageFromJSON(request.payload, db);
        // Calculate the response now to prevent errors after the draft has
        // already been sent.
        const responseOnSuccess = draft.toJSON();
        const sender = new SendmailClient(account, request.logger);
        await sender.send(draft);
        reply(responseOnSuccess);
      } catch (err) {
        respondWithError(request, reply, err);
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
          client_id: Joi.string(),
          account_id: Joi.string(),
          id: Joi.string(),
          object: Joi.string(),
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
    handler: async (request, reply) => {
      try {
        const accountId = request.auth.credentials.id;
        const db = await LocalDatabaseConnector.forAccount(accountId)
        const draft = await SendingUtils.findOrCreateMessageFromJSON(request.payload, db, false)
        await (draft.isSending = true);
        const savedDraft = await draft.save();
        reply(savedDraft.toJSON());
      } catch (err) {
        respondWithError(request, reply, err);
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
    path: '/send-multiple/{draftId}',
    config: {
      validate: {
        params: {
          draftId: Joi.string(),
        },
        payload: {
          send_to: recipient,
          body: Joi.string(),
        },
      },
    },
    handler: async (request, reply) => {
      try {
        const requestStarted = new Date();
        const account = request.auth.credentials;
        const {draftId} = request.params;
        SendingUtils.validateBase36(draftId, 'draftId')
        const sendTo = request.payload.send_to;
        const db = await LocalDatabaseConnector.forAccount(account.id)
        const draft = await SendingUtils.findMultiSendDraft(draftId, db)
        const {to, cc, bcc} = draft;
        const recipients = [].concat(to, cc, bcc);
        if (!recipients.find(contact => contact.email === sendTo.email)) {
          throw new SendingUtils.HTTPError(
            "Invalid sendTo, not present in message recipients",
            400
          );
        }

        const sender = new SendmailClient(account, request.logger);

        if (new Date() - requestStarted > SEND_TIMEOUT) {
          // Preemptively time out the request if we got stuck doing database work
          // -- we don't want clients to disconnect and then still send the
          // message.
          reply('Request timeout out.').code(504);
        }
        const response = await sender.sendCustomBody(draft, request.payload.body, {to: [sendTo]})
        reply(response);
      } catch (err) {
        respondWithError(request, reply, err);
      }
    },
  });

  // Closes out a multi-send session by marking the sending draft as sent
  // and moving it to the user's Sent folder.
  server.route({
    method: 'DELETE',
    path: '/send-multiple/{draftId}',
    config: {
      validate: {
        params: {
          draftId: Joi.string(),
        },
      },
    },
    handler: async (request, reply) => {
      try {
        const account = request.auth.credentials;
        const {draftId} = request.params;
        SendingUtils.validateBase36(draftId);

        const db = await LocalDatabaseConnector.forAccount(account.id);
        const draft = await SendingUtils.findMultiSendDraft(draftId, db);

        // gmail creates sent messages for each one, go through and delete them
        if (account.provider === 'gmail') {
          try {
            // TODO: use type: "PermananentDeleteMessage" once it's fully implemented
            await db.SyncbackRequest.create({
              type: "DeleteMessage",
              props: { messageId: draft.id },
            });
          } catch (err) {
            // Even if this fails, we need to finish the multi-send session,
            request.logger.error(err, err.logContext);
          }
        }

        const sender = new SendmailClient(account, request.logger);
        const rawMime = await sender.buildMime(draft);

        await db.SyncbackRequest.create({
          accountId: account.id,
          type: "SaveSentMessage",
          props: {rawMime},
        });

        await (draft.isSent = true);
        const savedDraft = await draft.save();
        reply(savedDraft.toJSON());
      } catch (err) {
        respondWithError(request, reply, err);
      }
    },
  });
};
