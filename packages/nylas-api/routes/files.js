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
          filename: Joi.string(),
          message_id: Joi.number().integer().min(0),
          content_type: Joi.string(),
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
        const query = request.query;
        const where = {};

        if (query.filename) {
          where.filename = query.filename;
        }
        if (query.message_id) {
          where.messageId = query.message_id;
        }
        if (query.content_type) {
          where.contentType = query.content_type;
        }

        File.findAll({
          where: where,
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
      request.getAccountDatabase().then(({File}) => {
        const {headers: {accept}} = request
        const {params: {id}} = request
        const account = request.auth.credentials

        File.findOne({where: {id}}).then((file) => {
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

  server.route({
    method: 'GET',
    path: '/files/{id}/download',
    config: {
      description: 'Returns binary data for file with specified id.',
      notes: 'Notes go here',
      tags: ['files'],
      validate: {
        params: {
          id: Joi.string(),
        },
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
          return file.fetch({account, db})
          .then((stream) => reply(stream))
        })
        .catch((error) => {
          console.log('Error fetching file: ', error)
          reply(error)
        })
      })
    },
  })
};
