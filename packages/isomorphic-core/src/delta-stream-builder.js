const _ = require('underscore');
const Rx = require('rx')
const stream = require('stream');
const DELTA_CONNECTION_TIMEOUT_MS = 15 * 60000;
const OBSERVABLE_TIMEOUT_MS = DELTA_CONNECTION_TIMEOUT_MS - (1 * 60000);

/**
 * A Transaction references objects that changed. This finds and inflates
 * those objects.
 *
 * Resolves to an array of transactions with their `attributes` set to be
 * the inflated model they reference.
 */
function inflateTransactions(db, accountId, transactions = [], sourceName) {
  const transactionJSONs = transactions.map((t) => (t.toJSON ? t.toJSON() : t))

  transactionJSONs.forEach((t) => {
    t.cursor = t.id;
    t.accountId = accountId;
  });

  const byModel = _.groupBy(transactionJSONs, "object");
  const byObjectIds = _.groupBy(transactionJSONs, "objectId");

  return Promise.all(Object.keys(byModel).map((modelName) => {
    const modelIds = byModel[modelName].filter(t => t.event !== 'delete').map(t => t.objectId);
    const modelConstructorName = modelName.charAt(0).toUpperCase() + modelName.slice(1);
    const ModelKlass = db[modelConstructorName]

    let includes = [];
    if (ModelKlass.requiredAssociationsForJSON) {
      includes = ModelKlass.requiredAssociationsForJSON(db)
    }
    return ModelKlass.findAll({
      where: {id: modelIds},
      include: includes,
    }).then((models) => {
      const remaining = _.difference(modelIds, models.map(m => `${m.id}`))
      if (remaining.length !== 0) {
        const badTrans = byModel[modelName].filter(t =>
          remaining.includes(t.objectId))
        console.error(`While inflating ${sourceName} transactions, we couldn't find models for some ${modelName} IDs`, remaining, badTrans)
      }
      for (const model of models) {
        const transactionsForModel = byObjectIds[model.id];
        for (const t of transactionsForModel) {
          t.attributes = model.toJSON();
        }
      }
    });
  })).then(() => transactionJSONs)
}

function stringifyTransactions(db, accountId, transactions = [], sourceName) {
  return inflateTransactions(db, accountId, transactions, sourceName)
  .then((transactionJSONs) => {
    return `${transactionJSONs.map(JSON.stringify).join("\n")}\n`;
  });
}

function transactionsSinceCursor(db, cursor, accountId) {
  return db.Transaction.streamAll({where: { id: {$gt: cursor}, accountId }});
}

module.exports = {
  DELTA_CONNECTION_TIMEOUT_MS: DELTA_CONNECTION_TIMEOUT_MS,
  buildAPIStream(request, {databasePromise, cursor, accountId, deltasSource}) {
    return databasePromise.then((db) => {
      const source = Rx.Observable.merge(
        transactionsSinceCursor(db, cursor, accountId).flatMap((ts) =>
          stringifyTransactions(db, accountId, ts, "initial")),
        deltasSource.flatMap((t) =>
          stringifyTransactions(db, accountId, [t], "new")),
        Rx.Observable.interval(1000).map(() => "\n")
      ).timeout(OBSERVABLE_TIMEOUT_MS);

      const outputStream = stream.Readable();
      outputStream._read = () => { return };
      const disposable = source.subscribe((str) => outputStream.push(str))
      request.on("disconnect", () => { disposable.dispose() });

      return outputStream;
    });
  },

  buildDeltaObservable({db, cursor, accountId, deltasSource}) {
    return Rx.Observable.merge(
      transactionsSinceCursor(db, cursor, accountId).flatMap((ts) =>
        inflateTransactions(db, accountId, ts, "initial")),
      deltasSource.flatMap((t) =>
        inflateTransactions(db, accountId, [t], "new"))
    )
  },

  buildCursor({databasePromise}) {
    return databasePromise.then(({Transaction}) => {
      return Transaction.findOne({order: [['id', 'DESC']]}).then((t) => {
        return t ? t.id : 0;
      });
    });
  },
}
