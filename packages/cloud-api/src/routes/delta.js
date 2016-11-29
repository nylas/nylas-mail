const {DatabaseConnector, PubsubConnector} = require(`cloud-core`);
const {deltaStreamBuilder} = require('isomorphic-core')

function transactionSource(db, request) {
  const {account} = request.auth.credentials;
  return PubsubConnector.observeDeltas(account.id)
    .flatMap((transactionJSON) => db.Transaction.build(transactionJSON))
}

function dbSource() {
  return DatabaseConnector.forShared.bind(DatabaseConnector)
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    handler: (request, reply) => {
      const outputStream = deltaStreamBuilder.buildStream(request,
          dbSource(), transactionSource)
      reply(outputStream)
    },
  });

  server.route({
    method: 'POST',
    path: '/delta/latest_cursor',
    handler: (request, reply) =>
      deltaStreamBuilder.lastTransactionReply(dbSource(), reply)
    ,
  });
};
