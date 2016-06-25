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
      request.getAccountDatabase()
      .then((db) => {
        const {headers: {accept}} = request
        const {params: {id}} = request
        const account = request.auth.credentials
        const query = db.Message.findOne({where: {id}})

        if (accept === 'message/rfc822') {
          query.then((message) => {
            message.fetchRaw({account, db})
            .then((raw) => reply(raw))
            .catch((error) => console.log(error))
          })
        } else {
          query.then((message) => {
            reply(Serialization.jsonStringify(message));
          })
        }
      })
    },
  })
};
