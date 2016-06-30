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
          'id': Joi.number().integer().min(0),
          'view': Joi.string().valid('expanded', 'count'),
          'subject': Joi.string(),
          'unread': Joi.boolean(),
          'starred': Joi.boolean(),
          'startedBefore': Joi.date().timestamp(),
          'startedAfter': Joi.date().timestamp(),
          'lastMessageBefore': Joi.date().timestamp(),
          'lastMessageAfter': Joi.date().timestamp(),
          'in': Joi.string().allow(Joi.number()),
          'limit': Joi.number().integer().min(1).max(2000).default(100),
          'offset': Joi.number().integer().min(0).default(0),
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
          // BEN TODO FIX BEFORE COMMITTING
          // include.push({
          //   model: Folder,
          //   where: { $or: [
          //     { id: query.in },
          //     { name: query.in },
          //     { role: query.in },
          //   ]},
          // });
        } else {
          include.push({model: Folder})
          include.push({model: Label})
        }

        if (query.view === 'expanded') {
          include.push({
            model: Message,
            as: 'messages',
            attributes: _.without(Object.keys(Message.attributes), 'body'),
          })
        } else {
          include.push({
            model: Message,
            as: 'messages',
            attributes: ['id'],
          })
        }

        if (query.view === 'count') {
          Thread.count({
            where: where,
            include: include,
          }).then((count) => {
            reply(Serialization.jsonStringify({count: count}));
          });
          return;
        }

        Thread.findAll({
          limit: request.query.limit,
          offset: request.query.offset,
          where: where,
          include: include,
        }).then((threads) => {
          // if the user requested the expanded viw, fill message.folder using
          // thread.folders, since it must be a superset.
          if (query.view === 'expanded') {
            for (const thread of threads) {
              for (const msg of thread.messages) {
                msg.folder = thread.folders.find(c => c.id === msg.folderId);
              }
            }
          }
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
      if (payload.folder_id) {
        createSyncbackRequest(request, reply, {
          type: "MoveToFolder",
          props: {
            folderId: request.payload.folder_id,
            threadId: request.params.id,
          },
        })
      }
      if (payload.unread === false) {
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
      }
      if (payload.starred === false) {
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
      }
    },
  });
};
