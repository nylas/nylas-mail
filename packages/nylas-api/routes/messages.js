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
        const {Message, Category} = db;
        Message.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
          include: {model: Category},
        }).then((messages) => {
          reply(Serialization.jsonStringify(messages));
        })
      })
    },
  });

  server.route({
    method: 'GET',
    path: '/messages/{id}',
    config: {
      description: 'Returns message for specified id.',
      notes: 'Notes go here',
      tags: ['messages'],
      validate: {
        params: {
          id: Joi.string(),
        },
      },
      response: {
        schema: Joi.alternatives().try(
          Serialization.jsonSchema('Message'),
          Joi.string()
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Message, Category} = db;
        const {headers: {accept}} = request;
        const {params: {id}} = request;
        const account = request.auth.credentials;

        Message.findOne({where: {id}, include: {model: Category}}).then((message) => {
          if (!message) {
            return reply.notFound(`Message ${id} not found`)
          }
          if (accept === 'message/rfc822') {
            return message.fetchRaw({account, db}).then((rawMessage) =>
              reply(rawMessage)
            )
          }
          return reply(Serialization.jsonStringify(message));
        })
        .catch((error) => {
          console.log('Error fetching message: ', error)
          reply(error)
        })
      })
    },
  })
};
