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
