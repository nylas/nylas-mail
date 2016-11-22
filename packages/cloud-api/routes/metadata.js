const Joi = require('joi');
const Serialization = require('../serialization');
const {DatabaseConnector} = require('cloud-core');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: `/metadata`,
    config: {
      description: `metadata`,
      notes: 'Notes go here',
      tags: ['metadata'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Metadata')
        ),
      },
    },
    handler: (request, reply) => {
      const {account} = request.auth.credentials;

      DatabaseConnector.forShared().then(({Metadata}) => {
        Metadata.findAll({
          accountId: account.id,
          limit: request.query.limit,
          offset: request.query.offset,
        }).then((items) => {
          reply(Serialization.jsonStringify(items));
        })
      })
    },
  });

  // TODO: consider adding some processing on routes that require display_name,
  // so that we smartly add prefixes or proper separators and things like that.

  server.route({
    method: 'POST',
    path: `/metadata`,
    config: {
      description: `Create metadata`,
      tags: ['metadata'],
      validate: {},
    },
    handler: (request, reply) => {
    },
  })

  server.route({
    method: 'PUT',
    path: `/metadata/{id}`,
    config: {
      description: `Update metadata`,
      tags: ['metadata'],
      validate: {
        params: {
          id: Joi.number().integer(),
        },
      },
    },
    handler: (request, reply) => {
    },
  })

  server.route({
    method: 'DELETE',
    path: `/metadata/{id}`,
    config: {
      description: `Delete metadata`,
      tags: ['metadata'],
      validate: {
        params: {
          id: Joi.number().integer(),
        },
      },
    },
    handler: (request, reply) => {
    },
  })
};
