const TransactionConnector = require('../../shared/transaction-connector')
const {deltaStreamBuilder} = require('isomorphic-core')

function transactionSource(db, request) {
  const accountId = request.auth.credentials.id;
  return TransactionConnector.getObservableForAccountId(accountId)
}

function dbSource(request) {
  return request.getAccountDatabase.bind(request)
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    handler: (request, reply) => {
      const outputStream = deltaStreamBuilder.buildStream(request,
          dbSource(request), transactionSource)
      reply(outputStream)
    },
  });

  server.route({
    method: 'POST',
    path: '/delta/latest_cursor',
    handler: (request, reply) =>
      deltaStreamBuilder.lastTransactionReply(dbSource(request), reply)
    ,
  });
};
