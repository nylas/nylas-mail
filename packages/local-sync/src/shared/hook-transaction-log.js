const _ = require('underscore')
const TransactionConnector = require('./transaction-connector')

module.exports = (db, sequelize) => {
  if (!db.Transaction) {
    throw new Error("Cannot enable transaction logging, there is no Transaction model class in this database.")
  }
  const isTransaction = ($modelOptions) => {
    return $modelOptions.name.singular === "transaction"
  }

  const allIgnoredFields = (changedFields) => {
    return _.isEqual(changedFields, ['syncState']);
  }

  const transactionLogger = (event) => {
    return ({dataValues, _changed, $modelOptions}) => {
      const changedFields = Object.keys(_changed)
      if ((isTransaction($modelOptions) || allIgnoredFields(changedFields))) {
        return;
      }

      const transactionData = Object.assign({event}, {
        object: $modelOptions.name.singular,
        objectId: dataValues.id,
        changedFields: changedFields,
      });

      db.Transaction.create(transactionData).then((transaction) => {
        TransactionConnector.notifyDelta(db.accountId, transaction);
      })
    }
  }

  sequelize.addHook("afterCreate", transactionLogger("create"))
  sequelize.addHook("afterUpdate", transactionLogger("modify"))
  sequelize.addHook("afterDelete", transactionLogger("delete"))
}
