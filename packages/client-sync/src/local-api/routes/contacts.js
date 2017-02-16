const Joi = require('joi');
const Serialization = require('../serialization');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/contacts',
    config: {
      description: 'Returns an array of contacts',
      notes: 'Notes go here',
      tags: ['contacts'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Contact')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Contact} = db;
        Contact.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
        }).then((contacts) => {
          reply(Serialization.jsonStringify(contacts))
        })
      })
    },
  })

  server.route({
    method: 'GET',
    path: '/contacts/{id}',
    config: {
      description: 'Returns a contact with specified id.',
      notes: 'Notes go here',
      tags: ['contacts'],
      validate: {
        params: {
          id: Joi.string(),
        },
      },
      response: {
        schema: Serialization.jsonSchema('Contact'),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then(({Contact}) => {
        const {params: {id}} = request

        Contact.findOne({where: {id}}).then((contact) => {
          if (!contact) {
            return reply.notFound(`Contact ${id} not found`)
          }
          return reply(Serialization.jsonStringify(contact))
        })
        .catch((error) => {
          request.info(error, 'Error fetching contacts')
        })
      })
    },
  })

  // TODO: This is a placeholder
  server.route({
    method: 'GET',
    path: '/contacts/rankings',
    config: {
      description: 'Returns contact rankings.',
      notes: 'Notes go here',
      tags: ['contacts'],
      response: {
        schema: Serialization.jsonSchema('Contact'),
      },
    },
    handler: (request, reply) => {
      reply('{}');
    },
  })
}
