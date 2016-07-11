const Joi = require('joi');
const Serialization = require('../serialization');
const {createSyncbackRequest, findFolderOrLabel} = require('../route-helpers');


module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/messages',
    config: {
      description: 'Returns all your messages.',
      notes: 'Notes go here',
      tags: ['messages'],
      validate: {
        query: {
          'unread': Joi.boolean(),
          'starred': Joi.boolean(),
          'subject': Joi.string(),
          'thread_id': Joi.number().integer().min(0),
          'received_before': Joi.date(),
          'received_after': Joi.date(),
          'filename': Joi.string(),
          'in': Joi.string(),
          'limit': Joi.number().integer().min(1).max(2000).default(100),
          'offset': Joi.number().integer().min(0).default(0),
        },
      },
      response: {
        schema: Joi.array().items(
          Serialization.jsonSchema('Message')
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Message, Folder, Label, File} = db;
        const query = request.query;
        const where = {};
        const include = [];

        if (query.unread != null) {
          where.unread = query.unread;
        }
        if (query.starred != null) {
          where.starred = query.starred;
        }
        if (query.subject) {
          where.subject = query.subject;
        }
        if (query.thread_id != null) {
          where.threadId = query.thread_id;
        }
        if (query.received_before) {
          where.date = {lt: query.received_before};
        }
        if (query.received_after) {
          if (where.date) {
            where.date.gt = query.received_after;
          } else {
            where.date = {gt: query.received_after};
          }
        }
        if (query.filename) {
          include.push({
            model: File,
            where: {filename: query.filename},
          })
        }

        let loadAssociatedModels = Promise.resolve();
        if (query.in) {
          loadAssociatedModels = findFolderOrLabel({Folder, Label}, query.in)
          .then((container) => {
            include.push({
              model: container.Model,
              where: {id: container.id},
            })
          })
        }

        loadAssociatedModels.then(() => {
          Message.findAll({
            where: where,
            limit: query.limit,
            offset: query.offset,
            include: include,
          }).then((messages) => {
            reply(Serialization.jsonStringify(messages));
          })
        })
      })
    },
  });

  server.route({
    method: 'GET',
    path: '/messages/{id}',
    config: {
      description: 'Returns message for specified id.',
      notes: 'Notes go here',
      tags: ['messages'],
      validate: {
        params: {
          id: Joi.string(),
        },
      },
      response: {
        schema: Joi.alternatives().try(
          Serialization.jsonSchema('Message'),
          Joi.string()
        ),
      },
    },
    handler: (request, reply) => {
      request.getAccountDatabase().then((db) => {
        const {Message, Folder, Label} = db;
        const {headers: {accept}} = request;
        const {params: {id}} = request;
        const account = request.auth.credentials;

        Message.findOne({where: {id}, include: [{model: Folder}, {model: Label}]}).then((message) => {
          if (!message) {
            return reply.notFound(`Message ${id} not found`)
          }
          if (accept === 'message/rfc822') {
            return message.fetchRaw({account, db, logger: request.logger})
            .then((rawMessage) =>
              reply(rawMessage)
            )
          }
          return reply(Serialization.jsonStringify(message));
        })
        .catch((err) => {
          request.logger.error(err, 'Error fetching message')
          reply(err)
        })
      })
    },
  })

  server.route({
    method: 'PUT',
    path: '/messages/{id}',
    config: {
      description: 'Update a message',
      tags: ['messages'],
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
          type: "MoveMessageToFolder",
          props: {
            folderId: request.payload.folder_id,
            messageId: request.params.id,
          },
        })
      }
      if (payload.unread === false) {
        createSyncbackRequest(request, reply, {
          type: "MarkMessageAsRead",
          props: {
            messageId: request.params.id,
          },
        })
      } else if (payload.unread === true) {
        createSyncbackRequest(request, reply, {
          type: "MarkMessageAsUnread",
          props: {
            messageId: request.params.id,
          },
        })
      }
      if (payload.starred === false) {
        createSyncbackRequest(request, reply, {
          type: "UnstarMessage",
          props: {
            messageId: request.params.id,
          },
        })
      } else if (payload.starred === true) {
        createSyncbackRequest(request, reply, {
          type: "StarMessage",
          props: {
            messageId: request.params.id,
          },
        })
      }
    },
  });
};
