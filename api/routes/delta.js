const DeltaStreamQueue = require(`${__base}/core/delta-stream-queue`);

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    config: {
      description: 'Returns deltas since timestamp then streams deltas',
      notes: 'Returns deltas since timestamp then streams deltas',
      tags: ['threads'],
      validate: {
        params: {
        },
      },
      response: {
        schema: null,
      },
    },
    handler: (request, reply) => {
      const outputStream = require('stream').Readable();
      outputStream._read = () => { return };
      const pushMsg = (msg = "\n") => outputStream.push(msg)

      request.getAccountDatabase()
      .then((db) => {
        return db.Transaction.findAll().then((transactions = []) => {
          transactions.map(JSON.stringify).forEach(pushMsg);
          DeltaStreamQueue.subscribe(db.accountId, pushMsg)
        })
      }).then(() => {
        const keepAlive = setInterval(pushMsg, 1000);
        request.on("disconnect", () => { clearTimeout(keepAlive) })
        return reply(outputStream)
      })
    },
  });
};
