const Rx = require('rx')
const _ = require('underscore');
const {PubsubConnector} = require(`nylas-core`);

function keepAlive(request) {
  const until = Rx.Observable.fromCallback(request.on)("disconnect")
  return Rx.Observable.interval(1000).map(() => "\n").takeUntil(until)
}

function inflateTransactions(db, transactionModels = []) {
  const transactions = _.pluck(transactionModels, "dataValues")
  transactions.forEach((t) => t.cursor = t.id);
  const byModel = _.groupBy(transactions, "object");
  const byObjectIds = _.groupBy(transactions, "objectId");

  return Promise.all(Object.keys(byModel).map((object) => {
    const ids = _.pluck(byModel[object], "objectId");
    const modelConstructorName = object.charAt(0).toUpperCase() + object.slice(1);
    const ModelKlass = db[modelConstructorName]
    let includes = [];
    if (ModelKlass.requiredAssociationsForJSON) {
      includes = ModelKlass.requiredAssociationsForJSON()
    }
    return ModelKlass.findAll({where: {id: ids}, include: includes})
    .then((models = []) => {
      for (const model of models) {
        model.dataValues.object = object
        const tsForId = byObjectIds[model.id];
        if (!tsForId || tsForId.length === 0) { continue; }
        for (const t of tsForId) { t.attributes = model.dataValues; }
      }
    })
  })).then(() => transactions.map(JSON.stringify).join("\n"))
}

function createOutputStream() {
  const outputStream = require('stream').Readable();
  outputStream._read = () => { return };
  outputStream.pushJSON = (msg) => {
    const jsonMsg = typeof msg === 'string' ? msg : JSON.stringify(msg);
    outputStream.push(jsonMsg);
  }
  return outputStream
}

function lastTransaction(db) {
  return db.Transaction.findOne({order: [['id', 'DESC']]})
}

function initialTransactions(db, request) {
  let cursor = (request.query || {}).cursor;
  const where = cursor ? {id: {$gt: cursor}} : {createdAt: {$gte: new Date()}}
  return db.Transaction
           .streamAll({where})
           .flatMap((objs) => inflateTransactions(db, objs))
}

module.exports = (server) => {
  server.route({
    method: 'GET',
    path: '/delta/streaming',
    handler: (request, reply) => {
      const outputStream = createOutputStream();

      request.getAccountDatabase().then((db) => {
        const source = Rx.Observable.merge(
          PubsubConnector.observeDeltas(request.auth.credentials.id),
          initialTransactions(db, request),
          keepAlive(request)
        ).subscribe(outputStream.pushJSON)

        request.on("disconnect", source.dispose.bind(source));
      });

      reply(outputStream)
    },
  });

  server.route({
    method: 'POST',
    path: '/delta/latest_cursor',
    handler: (request, reply) => request.getAccountDatabase().then((db) =>
      lastTransaction(db).then((t) => reply({cursor: t.id}))
    ),
  });
};
