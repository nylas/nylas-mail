const Joi = require('joi');
const Utils = require('../../shared/utils');
const {createSyncbackRequest} = require('../route-helpers');


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
      createSyncbackRequest(request, reply, {
        type: "SendMessage",
        props: {
          messagePayload: request.payload,
        },
        syncbackImmediately: true,
      })
    },
  });

  // Initiates a multi-send session by creating a new multi-send draft.
  server.route({
    method: 'POST',
    path: '/send-multiple',
    config: {
      validate: {
        payload: {
          message: {
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
          uses_open_tracking: Joi.boolean(),
          uses_link_tracking: Joi.boolean(),
        },
      },
    },
    async handler(request, reply) {
      createSyncbackRequest(request, reply, {
        type: "SendMessagePerRecipient",
        props: {
          messagePayload: request.payload.message,
          usesOpenTracking: request.payload.uses_open_tracking,
          usesLinkTracking: request.payload.uses_link_tracking,
        },
        syncbackImmediately: true,
      })
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
      const {messageId} = request.params;

      if (!Utils.isValidId(messageId)) {
        reply.badRequest(`messageId is not a base-36 integer`)
        return
      }
      createSyncbackRequest(request, reply, {
        type: "ReconcileSentMessagesPerRecipient",
        props: { messageId },
        syncbackImmediately: true,
      })
    },
  });
};
