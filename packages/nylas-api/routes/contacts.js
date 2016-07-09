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
          name: Joi.string(),
          email: Joi.string().email(),
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
        const query = request.query;
        const where = {};

        if (query.name) {
          where.name = {like: query.name};
        }
        if (query.email) {
          where.email = query.email;
        }

        Contact.findAll({
          where: where,
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
          console.log('Error fetching contacts: ', error)
          reply(error)
        })
      })
    },
  })
}
