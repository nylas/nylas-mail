const Joi = require('joi');
const Serialization = require('../serialization');
const {createSyncbackRequest} = require('../route-helpers');

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
            view: Joi.string().valid('expanded', 'count'),
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

    // TODO: consider adding some processing on routes that require display_name,
    // so that we smartly add prefixes or proper separators and things like that.

    server.route({
      method: 'POST',
      path: `/${term}`,
      config: {
        description: `Create ${term}`,
        tags: [term],
        validate: {},
        response: {
          schema: Serialization.jsonSchema('SyncbackRequest'),
        },
      },
      handler: (request, reply) => {
        if (request.payload.display_name) {
          createSyncbackRequest(request, reply, {
            type: "CreateFolder",
            props: {
              displayName: request.payload.display_name,
            },
          })
        }
      },
    })

    server.route({
      method: 'PUT',
      path: `/${term}/{id}`,
      config: {
        description: `Update ${term}`,
        tags: [term],
        validate: {
          params: {
            id: Joi.number().integer(),
          },
        },
        response: {
          schema: Serialization.jsonSchema('SyncbackRequest'),
        },
      },
      handler: (request, reply) => {
        if (request.payload.display_name) {
          createSyncbackRequest(request, reply, {
            type: "RenameFolder",
            props: {
              displayName: request.payload.display_name,
              id: request.params.id,
            },
          })
        }
      },
    })

    server.route({
      method: 'DELETE',
      path: `/${term}/{id}`,
      config: {
        description: `Delete ${term}`,
        tags: [term],
        validate: {
          params: {
            id: Joi.number().integer(),
          },
        },
        response: {
          schema: Serialization.jsonSchema('SyncbackRequest'),
        },
      },
      handler: (request, reply) => {
        createSyncbackRequest(request, reply, {
          type: "DeleteFolder",
          props: {
            id: request.params.id,
          },
        })
      },
    })
  });
};
