const Joi = require('joi');
const Serialization = require('../serialization');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/messages',
    config: {
      description: 'Returns all your messages.',
      notes: 'Notes go here',
      tags: ['messages'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Message')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Message} = db;
        Message.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
        }).then((messages) => {
          reply(Serialization.jsonStringify(messages));
        })
      })
    },
  });
};
