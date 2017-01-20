const Joi = require('joi');
const Serialization = require('../serialization');
const {createAndReplyWithSyncbackRequest} = require('../route-helpers');

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
      async handler(request, reply) {
        const db = await request.getAccountDatabase()
        const Klass = db[klass];
        const items = await Klass.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
        })
        reply(Serialization.jsonStringify(items));
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
        validate: {
          payload: {
            display_name: Joi.string().required(),
          },
        },
        response: {
          schema: Serialization.jsonSchema('SyncbackRequest'),
        },
      },
      async handler(request, reply) {
        const {payload} = request
        if (payload.display_name) {
          createAndReplyWithSyncbackRequest(request, reply, {
            type: "CreateCategory",
            props: {
              objectClass: klass,
              displayName: payload.display_name,
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
            id: Joi.string().required(),
          },
          payload: {
            display_name: Joi.string().required(),
          },
        },
        response: {
          schema: Serialization.jsonSchema('SyncbackRequest'),
        },
      },
      async handler(request, reply) {
        const {payload} = request
        if (payload.display_name) {
          if (klass === 'Label') {
            createAndReplyWithSyncbackRequest(request, reply, {
              type: "RenameLabel",
              props: {
                labelId: request.params.id,
                newLabelName: payload.display_name,
              },
            })
          } else {
            createAndReplyWithSyncbackRequest(request, reply, {
              type: "RenameFolder",
              props: {
                folderId: request.params.id,
                newFolderName: payload.display_name,
              },
            })
          }
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
            id: Joi.string().required(),
          },
        },
        response: {
          schema: Serialization.jsonSchema('SyncbackRequest'),
        },
      },
      handler: (request, reply) => {
        if (klass === 'Label') {
          createAndReplyWithSyncbackRequest(request, reply, {
            type: "DeleteLabel",
            props: {
              labelId: request.params.id,
            },
          })
        } else {
          createAndReplyWithSyncbackRequest(request, reply, {
            type: "DeleteFolder",
            props: {
              folderId: request.params.id,
            },
          })
        }
      },
    })
  });
};
