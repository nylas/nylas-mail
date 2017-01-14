const Joi = require('joi');
const stream = require('stream');
const _ = require('underscore');
const Serialization = require('../serialization');
const {createAndReplyWithSyncbackRequest} = require('../route-helpers')
const {searchClientForAccount} = require('../search');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/threads',
    config: {
      description: 'Returns threads',
      notes: 'Notes go here',
      tags: ['threads'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          offset: Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.alternatives().try([
          Joi.array().items(
            Serialization.jsonSchema('Thread')
          ),
          Joi.object().keys({
            count: Joi.number().integer().min(0),
          }),
        ]),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Thread, Folder, Label, Message} = db;
        Thread.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
          include: [
            {model: Folder},
            {model: Label},
            {
              model: Message,
              as: 'messages',
              attributes: _.without(Object.keys(Message.attributes), 'body'),
            },
          ],
        }).then((threads) => {
          reply(Serialization.jsonStringify(threads));
        })
      })
    },
  });

  server.route({
    method: 'GET',
    path: '/threads/search/streaming',
    config: {
      description: 'Returns threads',
      notes: 'Notes go here',
      tags: ['threads'],
      validate: {
        query: {
          limit: Joi.number().integer().min(1).max(2000).default(100),
          q: Joi.string(),
        },
      },
    },
    handler: async (request, reply) => {
      const account = request.auth.credentials;
      const db = await request.getAccountDatabase();
      const client = searchClientForAccount(account);
      const source = await client.searchThreads(db, request.query.q, request.query.limit);

      const outputStream = stream.Readable();
      outputStream._read = () => { return };
      const disposable = source.subscribe((str) => outputStream.push(str));
      request.on("disconnect", () => disposable.dispose());
      reply(outputStream);
    },
  });

  server.route({
    method: 'PUT',
    path: '/threads/{id}',
    config: {
      description: 'Update a thread',
      notes: 'Can move between folders',
      tags: ['threads'],
      validate: {
        params: {
          id: Joi.string(),
          payload: {
            unread: Joi.boolean(),
            starred: Joi.boolean(),
            labels: Joi.array(),
            label_ids: Joi.array(),
            folder: Joi.string(),
            folder_id: Joi.string(),
          },
        },
      },
      response: {
        schema: Serialization.jsonSchema('SyncbackRequest'),
      },
    },
    handler: (request, reply) => {
      const payload = request.payload
      if ((payload.folder_id || payload.folder) && (payload.label_ids || payload.labels)) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "SetThreadFolderAndLabels",
          props: {
            folderId: payload.folder_id || payload.folder,
            labelIds: payload.label_ids || payload.labels,
            threadId: request.params.id,
          },
        })
      } else if (payload.folder_id || payload.folder) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "MoveThreadToFolder",
          props: {
            folderId: payload.folder_id || payload.folder,
            threadId: request.params.id,
          },
        })
      } else if (payload.label_ids || payload.labels) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "SetThreadLabels",
          props: {
            labelIds: payload.label_ids || payload.labels,
            threadId: request.params.id,
          },
        })
      } else if (payload.unread === false) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "MarkThreadAsRead",
          props: {
            threadId: request.params.id,
          },
        })
      } else if (payload.unread === true) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "MarkThreadAsUnread",
          props: {
            threadId: request.params.id,
          },
        })
      } else if (payload.starred === false) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "UnstarThread",
          props: {
            threadId: request.params.id,
          },
        })
      } else if (payload.starred === true) {
        createAndReplyWithSyncbackRequest(request, reply, {
          type: "StarThread",
          props: {
            threadId: request.params.id,
          },
        })
      } else {
        reply("Invalid thread update").code(400)
      }
    },
  });
};
