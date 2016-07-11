const Joi = require('joi');
const {DatabaseConnector} = require(`nylas-core`);

module.exports = (server) => {
  server.route({
    method: 'PUT',
    path: '/accounts/{accountId}/clear-sync-error',
    config: {
      description: 'Clears the sync error for the given account',
      notes: 'Notes go here',
      tags: ['accounts', 'sync-error'],
      validate: {
        params: {
          accountId: Joi.number().integer(),
        },
      },
      response: {
        schema: Joi.string(),
      },
    },
    handler: (request, reply) => {
      DatabaseConnector.forShared().then(({Account}) => {
        Account.find({where: {id: request.params.accountId}}).then((account) => {
          account.syncError = null;
          account.save().then(() => reply("Success"));
        })
      })
    },
  });
};
