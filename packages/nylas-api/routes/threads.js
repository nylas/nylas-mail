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
          unread: Joi.boolean().allow(''),
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
        // the unread value will be '' if the url was just '/threads?unread'
        if (request.query.unread || request.query.unread === '') {
          Thread.findAll({
            where: {unreadCount: {gt: 0}},
            limit: 50,
          }).then((threads) => {
            reply(Serialization.jsonStringify(threads));
          })
        } else {
          Thread.findAll({limit: 50}).then((threads) => {
            reply(Serialization.jsonStringify(threads));
          })
        }
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
