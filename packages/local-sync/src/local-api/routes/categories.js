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
          const accountId = request.auth.credentials.id
          const db = await request.getAccountDatabase()
          const objectId = db[klass].hash({boxName: payload.display_name, accountId})

          createAndReplyWithSyncbackRequest(request, reply, {
            type: "CreateCategory",
            props: {
              objectId,
              object: klass.toLowerCase(),
              displayName: payload.display_name,
            },
            syncbackImmediately: true,
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
          const accountId = request.auth.credentials.id
          const db = await request.getAccountDatabase()
          const objectId = db[klass].hash({boxName: payload.display_name, accountId})

          if (klass === 'Label') {
            createAndReplyWithSyncbackRequest(request, reply, {
              type: "RenameLabel",
              props: {
                objectId,
                labelId: request.params.id,
                displayName: payload.display_name,
              },
              syncbackImmediately: true,
            })
          } else {
            createAndReplyWithSyncbackRequest(request, reply, {
              type: "RenameFolder",
              props: {
                objectId,
                folderId: request.params.id,
                displayName: payload.display_name,
              },
              syncbackImmediately: true,
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
