const Serialization = require('../serialization');
const {DatabaseConnector} = require('nylas-core');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/account',
    config: {
      description: 'Returns the current account.',
      notes: 'Notes go here',
      tags: ['accounts'],
      validate: {
        params: {
        },
      },
      response: {
        schema: Serialization.jsonSchema('Account'),
      },
    },
    handler: (request, reply) => {
      const account = request.auth.credentials;
      reply(Serialization.jsonStringify(account));
    },
  });

  server.route({
    method: 'DELETE',
    path: '/account',
    config: {
      description: 'Deletes the current account and all data from the Nylas Cloud.',
      notes: 'Notes go here',
      tags: ['accounts'],
      validate: {
        params: {
        },
      },
    },
    handler: (request, reply) => {
      const account = request.auth.credentials;
      account.destroy().then((saved) =>
        DatabaseConnector.destroyAccountDatabase(saved.id).then(() =>
          reply(Serialization.jsonStringify({status: 'success'}))
        )
      ).catch((err) => {
        reply(err).code(500);
      })
    },
  });
};
