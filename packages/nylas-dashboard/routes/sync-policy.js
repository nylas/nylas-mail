const Joi = require('joi');
const {SchedulerUtils} = require(`nylas-core`);

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/sync-policy/{account_id}',
    config: {
      description: 'Set the sync policy',
      notes: 'Notes go here',
      tags: ['sync-policy'],
      validate: {
        params: {
          account_id: Joi.number().integer(),
        },
        payload: {
          sync_policy: Joi.string(),
        },
      },
      response: {
        schema: Joi.string(),
      },
    },
    handler: (request, reply) => {
      const newPolicy = JSON.parse(request.payload.sync_policy);
      SchedulerUtils.assignPolicy(request.params.account_id, newPolicy)
      .then(() => reply("Success"));
    },
  });
};
