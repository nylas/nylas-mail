const Joi = require('joi');
const Serialization = require('../serialization');

module.exports = (server) => {
  ['Folder', 'Label'].forEach((klass) => {
    const term = `${klass.toLowerCase()}s`;

    server.route({
      method: 'GET',
      path: `/${term}`,
      config: {
        description: `${term}`,
        notes: 'Notes go here',
        tags: [term],
        validate: {
          query: {
            limit: Joi.number().integer().min(1).max(2000).default(100),
            offset: Joi.number().integer().min(0).default(0),
          },
        },
        response: {
          schema: Joi.array().items(
            Serialization.jsonSchema(klass)
          ),
        },
      },
      handler: (request, reply) => {
        request.getAccountDatabase().then((db) => {
          const Klass = db[klass];
          Klass.findAll({
            limit: request.query.limit,
            offset: request.query.offset,
          }).then((items) => {
            reply(Serialization.jsonStringify(items));
          })
        })
      },
    });
  });
};
