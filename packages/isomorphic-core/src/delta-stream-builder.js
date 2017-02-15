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
  buildAPIStream(request, {databasePromise, cursor, accountId, deltasSource}) {
    return databasePromise.then((db) => {
      const source = Rx.Observable.merge(
        transactionsSinceCursor(db, cursor, accountId).flatMap((ts) =>
          stringifyTransactions(db, accountId, ts, "initial")),
        deltasSource.flatMap((t) =>
          stringifyTransactions(db, accountId, [t], "new")),
        Rx.Observable.interval(1000).map(() => "\n")
      )

      const outputStream = stream.Readable();
      outputStream._read = () => { return };
      const disposable = source.subscribe((str) => outputStream.push(str))
      // See the following for why we need to set up the listeners on the raw
      // stream.
      // http://stackoverflow.com/questions/26221000/detecting-when-a-long-request-has-ended-in-nodejs-express
      // https://github.com/hapijs/discuss/issues/322#issuecomment-235999544
      //
      // Hapi's disconnect event only fires on error or unexpected aborts: https://hapijs.com/api#response-events
      request.raw.req.on('error', (error) => {
        request.logger.error({error}, 'Delta connection stream errored')
        disposable.dispose()
      })
      request.raw.req.on('close', () => {
        request.logger.info('Delta connection stream was closed')
        disposable.dispose()
      })
      request.raw.req.on('end', () => {
        request.logger.info('Delta connection stream ended')
        disposable.dispose()
      })
      request.on("disconnect", () => {
        request.logger.info('Delta connection request was disconnected')
        disposable.dispose()
      });

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
