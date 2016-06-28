const Joi = require('joi');
const Serialization = require('../serialization');


module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/files',
    config: {
      description: 'Returns an array of file metadata.',
      notes: 'Notes go here',
      tags: ['files'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('File')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {File} = db;
        File.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
        }).then((files) => {
          reply(Serialization.jsonStringify(files));
        })
      })
    },
  });

  server.route({
    method: 'GET',
    path: '/files/{id}',
    config: {
      description: 'Returns file with specified id.',
      notes: 'Notes go here',
      tags: ['files'],
      validate: {
        params: {
          id: Joi.string(),
        },
      },
      response: {
        schema: Joi.alternatives().try(
          Serialization.jsonSchema('File'),
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

        db.File.findOne({where: {id}})
        .then((file) => {
          if (!file) {
            return reply.notFound(`File ${id} not found`)
          }
          return reply(Serialization.jsonStringify(file));
        })
        .catch((error) => {
          console.log('Error fetching file: ', error)
          reply(error)
        })
      })
    },
  })
};