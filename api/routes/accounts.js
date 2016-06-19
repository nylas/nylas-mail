const Serialization = require('../serialization');

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
};
