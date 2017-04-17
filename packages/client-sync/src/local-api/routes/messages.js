const Joi = require('joi');
const {Provider} = require('isomorphic-core')
const Serialization = require('../serialization');
const {createAndReplyWithSyncbackRequest} = require('../route-helpers');


module.exports = (server) => {
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
        const {Message, Folder, Label, File} = db;
        const {headers: {accept}} = request;
        const {params: {id}} = request;
        const account = request.auth.credentials;

        Message.findOne({where: {id},
          include: [{model: Folder}, {model: Label}, {model: File}]})
        .then((message) => {
          if (!message) {
            return reply.notFound(`Message ${id} not found`)
          }
          if (accept === 'message/rfc822') {
            return message.fetchRaw({account, logger: request.logger})
            .then((rawMessage) =>
              reply(rawMessage)
            )
          }
          return reply(Serialization.jsonStringify(message));
        })
        .catch((err) => {
          request.logger.error(err, 'Error fetching message')
          reply(err)
        })
      })
    },
  })
};
