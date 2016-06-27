const Joi = require('joi');
const Serialization = require('../serialization');

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
          id: Joi.number().integer().min(0),
          unread: Joi.boolean(),
          starred: Joi.boolean(),
          startedBefore: Joi.date().timestamp(),
          startedAfter: Joi.date().timestamp(),
          lastMessageBefore: Joi.date().timestamp(),
          lastMessageAfter: Joi.date().timestamp(),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Thread')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Thread} = db;
        const query = request.query;
        const where = {};

        if (query.id) {
          where.id = query.id;
        }

        // Boolean queries
        if (query.unread) {
          where.unreadCount = {gt: 0};
        } else if (query.unread !== undefined) {
          where.unreadCount = 0;
        }
        if (query.starred) {
          where.starredCount = {gt: 0};
        } else if (query.starred !== undefined) {
          where.starredCount = 0;
        }

        // Timestamp queries
        if (query.lastMessageBefore) {
          where.lastMessageReceivedTimestamp = {lt: query.lastMessageBefore};
        }
        if (query.lastMessageAfter) {
          if (where.lastMessageReceivedTimestamp) {
            where.lastMessageReceivedTimestamp.gt = query.lastMessageAfter;
          } else {
            where.lastMessageReceivedTimestamp = {gt: query.lastMessageAfter};
          }
        }
        if (query.startedBefore) {
          where.firstMessageTimestamp = {lt: query.startedBefore};
        }
        if (query.startedAfter) {
          if (where.firstMessageTimestamp) {
            where.firstMessageTimestamp.gt = query.startedAfter;
          } else {
            where.firstMessageTimestamp = {gt: query.startedAfter};
          }
        }

        Thread.findAll({
          where: where,
          limit: 50,
        }).then((threads) => {
          reply(Serialization.jsonStringify(threads));
        })
      })
    },
  });

  server.route({
    method: 'PUT',
    path: '/threads/${id}',
    config: {
      description: 'Update a thread',
      notes: 'Can move between folders',
      tags: ['threads'],
      validate: {
        params: {
          payload: {
            folder_id: Joi.string(),
          },
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Thread')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        db.SyncbackRequest.create({
          type: "MoveToFolder",
          props: {
            folderId: request.params.folder_id,
            threadId: request.params.id,
          },
        }).then((syncbackRequest) => {
          reply(Serialization.jsonStringify(syncbackRequest))
        })
      })
    },
  });
};
