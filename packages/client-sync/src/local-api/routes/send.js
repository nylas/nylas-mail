const Joi = require('joi');
const {ModelUtils} = require('isomorphic-core');
const {createAndReplyWithSyncbackRequest} = require('../route-helpers');


// const recipient = Joi.object().keys({
//   name: Joi.string().required(),
//   email: Joi.string().email().required(),
//   // Rest are optional
//   account_id: Joi.string(),
//   client_id: Joi.string(),
//   id: Joi.string(),
//   thirdPartyData: Joi.object(),
//   server_id: Joi.string(),
//   object: Joi.string(),
// });

// const recipientList = Joi.array().items(recipient);

module.exports = (server) => {
  // Closes out a multi-send session by marking the sending draft as sent
  // and moving it to the user's Sent folder.
  server.route({
    method: 'POST',
    path: '/ensure-message-in-sent-folder/{messageId}',
    config: {
      validate: {
        payload: {
          customSentMessage: Joi.boolean(),
        },
        params: {
          messageId: Joi.string(),
        },
      },
    },
    async handler(request, reply) {
      const {messageId} = request.params;
      const {customSentMessage} = request.payload;

      if (!ModelUtils.isValidId(messageId)) {
        reply.badRequest(`messageId is not a base-36 integer`)
        return
      }
      createAndReplyWithSyncbackRequest(request, reply, {
        type: "EnsureMessageInSentFolder",
        props: { messageId, customSentMessage },
      })
    },
  });
};
