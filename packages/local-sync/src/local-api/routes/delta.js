const Joi = require('joi');
const TransactionConnector = require('../../shared/transaction-connector')
const {DeltaStreamBuilder} = require('isomorphic-core')

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    config: {
      validate: {
        query: {
          cursor: Joi.string().required(),
        },
      },
    },
    handler: (request, reply) => {
      const account = request.auth.credentials;

      DeltaStreamBuilder.buildStream(request, {
        cursor: request.query.cursor,
        accountId: account.id,
        databasePromise: request.getAccountDatabase(),
        deltasSource: TransactionConnector.getObservableForAccountId(account.id),
      }).then((stream) => {
        reply(stream)
      });
    },
  });

  server.route({
    method: 'POST',
    path: '/delta/latest_cursor',
    handler: (request, reply) => {
      DeltaStreamBuilder.buildCursor({
        databasePromise: request.getAccountDatabase(),
      }).then((cursor) => {
        reply({cursor})
      });
    },
  });
};
