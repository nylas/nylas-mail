const _ = require('underscore');
const Rx = require('rx')
const stream = require('stream');

function stringifyTransactions(db, transactions = []) {
  const transactionJSONs = transactions.map((t) => (t.toJSON ? t.toJSON() : t))
  transactionJSONs.forEach((t) => { t.cursor = t.id });

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
      for (const model of models) {
        const transactionsForModel = byObjectIds[model.id];
        for (const t of transactionsForModel) {
          t.attributes = model.toJSON();
        }
      }
    });
  })).then(() => {
    return `${transactionJSONs.map(JSON.stringify).join("\n")}\n`;
  });
}

module.exports = {
  buildStream(request, {databasePromise, cursor, accountId, deltasSource}) {
    return databasePromise.then((db) => {
      const initialSource = db.Transaction.streamAll({where: { id: {$gt: cursor}, accountId }});

      const source = Rx.Observable.merge(
        initialSource.flatMap((t) => stringifyTransactions(db, t)),
        deltasSource.flatMap((t) => stringifyTransactions(db, [t])),
        Rx.Observable.interval(1000).map(() => "\n")
      )

      const outputStream = stream.Readable();
      outputStream._read = () => { return };
      const disposable = source.subscribe((str) => outputStream.push(str))
      request.on("disconnect", () => disposable.dispose());

      return outputStream;
    });
  },

  buildCursor({databasePromise}) {
    return databasePromise.then(({Transaction}) => {
      return Transaction.findOne({order: [['id', 'DESC']]}).then((t) => {
        return t ? t.id : 0;
      });
    });
  },
}
