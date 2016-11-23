const Joi = require('joi');
const LocalDatabaseConnector = require('../../shared/local-database-connector');

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/syncback-requests/{account_id}',
    config: {
      description: 'Get the SyncbackRequests for an account',
      notes: 'Notes go here',
      tags: ['syncback-requests'],
      validate: {
        params: {
          account_id: Joi.number().integer(),
        },
      },
      response: {
        schema: Joi.string(),
      },
    },
    handler: (request, reply) => {
      LocalDatabaseConnector.forAccount(request.params.account_id).then((db) => {
        const {SyncbackRequest} = db;
        SyncbackRequest.findAll().then((syncbackRequests) => {
          reply(JSON.stringify(syncbackRequests))
        });
      });
    },
  });

  server.route({
    method: 'GET',
    path: '/syncback-requests/{account_id}/counts',
    config: {
      description: 'Get stats on the statuses of SyncbackRequests',
      notes: 'Notes go here',
      tags: ['syncback-requests'],
      validate: {
        params: {
          account_id: Joi.number().integer(),
        },
        query: {
          since: Joi.date().timestamp(),
        },
      },
      response: {
        schema: Joi.string(),
      },
    },
    handler: (request, reply) => {
      LocalDatabaseConnector.forAccount(request.params.account_id).then((db) => {
        const {SyncbackRequest} = db;

        const counts = {
          'new': null,
          'succeeded': null,
          'failed': null,
        }

        const where = {};
        if (request.query.since) {
          where.createdAt = {gt: request.query.since};
        }

        const countPromises = [];
        for (const status of Object.keys(counts)) {
          where.status = status.toUpperCase();
          countPromises.push(
            SyncbackRequest.count({where: where}).then((count) => {
              counts[status] = count;
            })
          );
        }

        Promise.all(countPromises).then(() => {
          reply(JSON.stringify(counts));
        })
      });
    },
  });
};
