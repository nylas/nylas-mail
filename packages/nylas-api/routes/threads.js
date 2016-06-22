const Joi = require('joi');
const Serialization = require('../serialization');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/threads',
    config: {
      description: 'Returns threads',
      notes: 'Notes go here',
      tags: ['threads'],
      validate: {
        params: {
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Account')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Thread} = db;
        Thread.findAll({limit: 50}).then((threads) => {
          reply(Serialization.jsonStringify(threads));
        })
      })
    },
  });
};
