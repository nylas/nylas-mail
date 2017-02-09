const Joi = require('joi');
const Utils = require('../../shared/utils');
const SyncbackTaskFactory = require('../../local-sync-worker/syncback-task-factory');
const {runSyncbackTask} = require('../../local-sync-worker/syncback-task-helpers');
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
  server.route({
    method: 'POST',
    path: '/send',
    config: {
    },
    async handler(request, reply) {
      const account = request.auth.credentials;
      const syncbackRequest = await createAndReplyWithSyncbackRequest(request, reply, {
        type: "SendMessage",
        props: {
          messagePayload: request.payload,
        },
        // TODO this is a hack to run send outside the sync loop. This should be
        // refactored when we implement the sync scheduler
        wakeSync: false,
      })

      const sendTask = SyncbackTaskFactory.create(account, syncbackRequest)
      const db = await request.getAccountDatabase()
      await runSyncbackTask({
        task: sendTask,
        runTask: (t) => t.run(db),
        logger: request.logger.child(),
      })
    },
  });

  // Initiates a multi-send session by creating a new multi-send draft.
  server.route({
    method: 'POST',
    path: '/send-per-recipient',
    config: {
    },
    async handler(request, reply) {
      const account = request.auth.credentials;
      const syncbackRequest = await createAndReplyWithSyncbackRequest(request, reply, {
        type: "SendMessagePerRecipient",
        props: {
          messagePayload: request.payload.message,
          usesOpenTracking: request.payload.uses_open_tracking,
          usesLinkTracking: request.payload.uses_link_tracking,
        },
        // TODO this is a hack to run send outside the sync loop. This should be
        // refactored when we implement the sync scheduler
        wakeSync: false,
      })

      const sendTask = SyncbackTaskFactory.create(account, syncbackRequest)
      const db = await request.getAccountDatabase()
      await runSyncbackTask({
        task: sendTask,
        runTask: (t) => t.run(db),
        logger: request.logger.child(),
      })
    },
  });

  // Closes out a multi-send session by marking the sending draft as sent
  // and moving it to the user's Sent folder.
  server.route({
    method: 'POST',
    path: '/ensure-message-in-sent-folder/{messageId}',
    config: {
      validate: {
        payload: {
          sentPerRecipient: Joi.boolean(),
        },
        params: {
          messageId: Joi.string(),
        },
      },
    },
    async handler(request, reply) {
      const {messageId} = request.params;
      const {sentPerRecipient} = request.payload;

      if (!Utils.isValidId(messageId)) {
        reply.badRequest(`messageId is not a base-36 integer`)
        return
      }
      createAndReplyWithSyncbackRequest(request, reply, {
        type: "EnsureMessageInSentFolder",
        props: { messageId, sentPerRecipient },
      })
    },
  });
};
