const PubsubConnector = require('./pubsub-connector')

module.exports = (db, sequelize) => {
  const parseHookData = ({dataValues, _changed, $modelOptions}) => {
    return {
      objectId: dataValues.id,
      modelName: $modelOptions.name.singular,
      changedFields: _changed,
    }
  }

  const isTransaction = ({$modelOptions}) => {
    return $modelOptions.name.singular === "Transaction"
  }

  const transactionLogger = (type) => {
    return (sequelizeHookData) => {
      if (isTransaction(sequelizeHookData)) return;
      const transactionData = Object.assign({type: type},
        parseHookData(sequelizeHookData)
      );
      db.Transaction.create(transactionData);
      transactionData.object = sequelizeHookData.dataValues;

      PubsubConnector.notifyAccountDeltas(db.accountId, transactionData);
    }
  }

  sequelize.addHook("afterCreate", transactionLogger("create"))
  sequelize.addHook("afterUpdate", transactionLogger("update"))
  sequelize.addHook("afterDelete", transactionLogger("delete"))
}
