const Joi = require('joi');
const {getLastSyncActivityForAccount, getLastSyncActivity} = require('../../shared/sync-activity').default

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/health',
    config: {
      description: 'Returns information about the last recorded sync activity for all accounts',
      tags: ['health'],
    },
    handler: (request, reply) => {
      let response;
      try {
        response = getLastSyncActivity()
        response = JSON.stringify(response)
        reply(response)
      } catch (err) {
        const context = response ? "" : "Could not retrieve last sync activity"
        request.logger.error(err, context)
        reply(err)
      }
    },
  })

  server.route({
    method: 'GET',
    path: '/health/{accountId}',
    config: {
      description: 'Returns information about the last recorded sync activity for the specified account',
      tags: ['health'],
      validate: {
        params: {
          accountId: Joi.string(),
        },
      },
    },
    handler: (request, reply) => {
      let response;
      try {
        const {accountId} = request.params
        response = getLastSyncActivityForAccount(accountId)
        response = JSON.stringify(response)
        reply(response)
      } catch (err) {
        const context = response ? "" : "Could not retrieve last sync activity"
        request.logger.error(err, context)
        reply(err)
      }
    },
  })
};
