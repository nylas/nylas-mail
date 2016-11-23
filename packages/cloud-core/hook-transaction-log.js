const PubsubConnector = require('./pubsub-connector');

module.exports = (db, sequelize) => {
  const isTransaction = ($modelOptions) => {
    return $modelOptions.name.singular === "transaction"
  }

  const transactionLogger = (event) => {
    return ({dataValues, _changed, $modelOptions}) => {
      if (isTransaction($modelOptions)) {
        return;
      }

      let name = $modelOptions.name.singular;
      if (name === 'metadatum') {
        name = 'metadata';
      }

      const transactionData = Object.assign({event}, {
        object: name,
        objectId: dataValues.id,
        changedFields: Object.keys(_changed),
      });

      db.Transaction.create(transactionData).then((transaction) => {
        PubsubConnector.notifyDelta(dataValues.accountId, transaction.toJSON());
      })
    }
  }

  sequelize.addHook("afterCreate", transactionLogger("create"))
  sequelize.addHook("afterUpdate", transactionLogger("modify"))
  sequelize.addHook("afterDelete", transactionLogger("delete"))
}
