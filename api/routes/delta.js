const DeltaStreamQueue = require(`${__base}/core/delta-stream-queue`);

function findParams(queryParams = {}) {
  const since = new Date(queryParams.since || Date.now())
  return {where: {createdAt: {$gte: since}}}
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    handler: (request, reply) => {
      const outputStream = require('stream').Readable();
      outputStream._read = () => { return };
      const sendMsg = (msg = "\n") => outputStream.push(msg);

      request.getAccountDatabase()
      .then((db) => {
        return db.Transaction.findAll(findParams(request.query))
        .then((transactions = []) => {
          transactions.map(JSON.stringify).forEach(sendMsg);
          DeltaStreamQueue.subscribe(db.accountId, sendMsg)
        })
      }).then(() => {
        const keepAlive = setInterval(sendMsg, 1000);
        request.on("disconnect", () => { clearTimeout(keepAlive) })
        return reply(outputStream)
      })
    },
  });
};
