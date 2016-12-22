const _ = require('underscore');
const Rx = require('rx')
const stream = require('stream');

/**
 * A Transaction references objects that changed. This finds and inflates
 * those objects.
 *
 * Resolves to an array of transactions with their `attributes` set to be
 * the inflated model they reference.
 */
function inflateTransactions(db, accountId, transactions = []) {
  const transactionJSONs = transactions.map((t) => (t.toJSON ? t.toJSON() : t))
  transactionJSONs.forEach((t) => {
    t.cursor = t.id;
    t.accountId = accountId;
  });

  const byModel = _.groupBy(transactionJSONs, "object");
  const byObjectIds = _.groupBy(transactionJSONs, "objectId");

  return Promise.all(Object.keys(byModel).map((modelName) => {
    const modelIds = byModel[modelName].map(t => t.objectId);
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
      if (models.length !== modelIds.length) {
        console.error("Couldn't find a model for some IDs", modelName, modelIds, models)
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

function stringifyTransactions(db, accountId, transactions = []) {
  return inflateTransactions(db, accountId, transactions).then((transactionJSONs) => {
    return `${transactionJSONs.map(JSON.stringify).join("\n")}\n`;
  });
}

function transactionsSinceCursor(db, cursor, accountId) {
  return db.Transaction.streamAll({where: { id: {$gt: cursor}, accountId }});
}

module.exports = {
  buildAPIStream(request, {databasePromise, cursor, accountId, deltasSource}) {
    return databasePromise.then((db) => {
      const initialSource = transactionsSinceCursor(db, cursor, accountId);
      const source = Rx.Observable.merge(
        initialSource.flatMap((ts) => stringifyTransactions(db, accountId, ts)),
        deltasSource.flatMap((t) => stringifyTransactions(db, accountId, [t])),
        Rx.Observable.interval(1000).map(() => "\n")
      )

      const outputStream = stream.Readable();
      outputStream._read = () => { return };
      const disposable = source.subscribe((str) => outputStream.push(str))
      request.on("disconnect", () => disposable.dispose());

      return outputStream;
    });
  },

  buildDeltaObservable({db, cursor, accountId, deltasSource}) {
    const initialSource = transactionsSinceCursor(db, cursor, accountId);
    return Rx.Observable.merge(
      initialSource.flatMap((ts) => inflateTransactions(db, accountId, ts)),
      deltasSource.flatMap((t) => inflateTransactions(db, accountId, [t]))
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
