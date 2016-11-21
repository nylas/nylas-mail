const Joi = require('joi');

// TODO: This is a placeholder
module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/drafts',
    config: {
      description: 'Returns drafts.',
      notes: 'Notes go here',
      tags: ['drafts'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
          view: Joi.string().valid('count'),
        },
      },
      response: {
        schema: Joi.array(),
      },
    },
    handler: (request, reply) => {
      reply('[]');
    },
  });
}
