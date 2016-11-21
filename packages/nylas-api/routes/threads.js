const Joi = require('joi');
const _ = require('underscore');
const Serialization = require('../serialization');
const {createSyncbackRequest} = require('../route-helpers')

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
      if (payload.folder_id || payload.folder) {
        createSyncbackRequest(request, reply, {
          type: "MoveToFolder",
          props: {
            folderId: request.payload.folder_id || request.payload.folder,
            threadId: request.params.id,
          },
        })
      } else if (payload.unread === false) {
        createSyncbackRequest(request, reply, {
          type: "MarkThreadAsRead",
          props: {
            threadId: request.params.id,
          },
        })
      } else if (payload.unread === true) {
        createSyncbackRequest(request, reply, {
          type: "MarkThreadAsUnread",
          props: {
            threadId: request.params.id,
          },
        })
      } else if (payload.starred === false) {
        createSyncbackRequest(request, reply, {
          type: "UnstarThread",
          props: {
            threadId: request.params.id,
          },
        })
      } else if (payload.starred === true) {
        createSyncbackRequest(request, reply, {
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
