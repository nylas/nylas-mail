const Joi = require('joi');
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
          'id': Joi.number().integer().min(0),
          'subject': Joi.string(),
          'unread': Joi.boolean(),
          'starred': Joi.boolean(),
          'startedBefore': Joi.date().timestamp(),
          'startedAfter': Joi.date().timestamp(),
          'lastMessageBefore': Joi.date().timestamp(),
          'lastMessageAfter': Joi.date().timestamp(),
          'in': Joi.string().allow(Joi.number()),
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
        const {Thread, Category} = db;
        const query = request.query;
        const where = {};
        const include = [];

        if (query.id) {
          where.id = query.id;
        }
        if (query.subject) {
          // the 'like' operator is case-insenstive in sequelite and for
          // non-binary strings in mysql
          where.subject = {like: query.subject};
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
          where.lastMessageReceivedDate = {lt: query.lastMessageBefore};
        }
        if (query.lastMessageAfter) {
          if (where.lastMessageReceivedDate) {
            where.lastMessageReceivedDate.gt = query.lastMessageAfter;
          } else {
            where.lastMessageReceivedDate = {gt: query.lastMessageAfter};
          }
        }
        if (query.startedBefore) {
          where.firstMessageDate = {lt: query.startedBefore};
        }
        if (query.startedAfter) {
          if (where.firstMessageDate) {
            where.firstMessageDate.gt = query.startedAfter;
          } else {
            where.firstMessageDate = {gt: query.startedAfter};
          }
        }

        // Association queries
        if (query.in) {
          include.push({
            model: Category,
            where: { $or: [
              { id: query.in },
              { name: query.in },
              { role: query.in },
            ]},
          });
        }

        Thread.findAll({
          where: where,
          include: include,
          limit: 50,
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
      createSyncbackRequest(request, reply, {
        type: "MoveToFolder",
        props: {
          folderId: request.payload.folder_id,
          threadId: request.params.id,
        },
      })
    },
  });

  server.route({
    method: 'POST',
    path: '/threads/{id}/markread',
    config: {
      description: 'Mark a thread as read.',
      tags: ['threads'],
      handler: (request, reply) => {
        createSyncbackRequest(request, reply, {
          type: "MarkThreadAsRead",
          props: {
            threadId: request.params.id,
          },
        })
      },
    },
  })
};
