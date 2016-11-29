const _ = require('underscore');
const Rx = require('rx')
const stream = require('stream');

function keepAlive(request) {
  const until = Rx.Observable.fromCallback(request.on)("disconnect")
  return Rx.Observable.interval(1000).map(() => "\n").takeUntil(until)
}

function inflateTransactions(db, transactionModels = []) {
  let models = transactionModels;
  if (!(_.isArray(models))) { models = [transactionModels] }
  const transactions = models.map((mod) => mod.toJSON())
  transactions.forEach((t) => { t.cursor = t.id });
  const byModel = _.groupBy(transactions, "object");
  const byObjectIds = _.groupBy(transactions, "objectId");

  return Promise.all(Object.keys(byModel).map((object) => {
    const ids = _.pluck(byModel[object], "objectId");
    const modelConstructorName = object.charAt(0).toUpperCase() + object.slice(1);
    const ModelKlass = db[modelConstructorName]
    let includes = [];
    if (ModelKlass.requiredAssociationsForJSON) {
      includes = ModelKlass.requiredAssociationsForJSON(db)
    }
    return ModelKlass.findAll({where: {id: ids}, include: includes})
    .then((objs = []) => {
      for (const model of objs) {
        const tsForId = byObjectIds[model.id];
        if (!tsForId || tsForId.length === 0) { continue; }
        for (const t of tsForId) { t.attributes = model.toJSON(); }
      }
    })
  })).then(() => `${transactions.map(JSON.stringify).join("\n")}\n`)
}

function createOutputStream() {
  const outputStream = stream.Readable();
  outputStream._read = () => { return };
  outputStream.pushJSON = (msg) => {
    const jsonMsg = typeof msg === 'string' ? msg : JSON.stringify(msg);
    outputStream.push(jsonMsg);
  }
  return outputStream
}

function initialTransactions(db, request) {
  const cursor = (request.query || {}).cursor;
  const where = cursor ? {id: {$gt: cursor}} : {createdAt: {$gte: new Date()}}
  return db.Transaction
           .streamAll({where})
           .flatMap((objs) => inflateTransactions(db, objs))
}

function inflatedIncomingTransaction(db, request, transactionSource) {
  transactionSource.flatMap((t) => inflateTransactions(db, [t]))
}

module.exports = {
  buildStream(request, dbSource, transactionSource) {
    const outputStream = createOutputStream();

    dbSource().then((db) => {
      const source = Rx.Observable.merge(
        inflatedIncomingTransaction(db, request, transactionSource(db, request)),
        initialTransactions(db, request),
        keepAlive(request)
      ).subscribe(outputStream.pushJSON)

      request.on("disconnect", source.dispose.bind(source));
    });

    return outputStream
  },

  lastTransactionReply(dbSource, reply) {
    dbSource().then((db) => {
      db.Transaction.findOne({order: [['id', 'DESC']]})
      .then((t) => {
        reply({cursor: (t || {}).id})
      })
    })
  },
}
