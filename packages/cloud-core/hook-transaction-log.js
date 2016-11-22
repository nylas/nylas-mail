const _ = require('underscore')

module.exports = (db, sequelize) => {
  const isTransaction = ($modelOptions) => {
    return $modelOptions.name.singular === "transaction"
  }

  const allIgnoredFields = (changedFields) => {
    const IGNORED_FIELDS = ["syncState", "version"];
    return _.difference(Object.keys(changedFields), IGNORED_FIELDS).length === 0
  }

  const transactionLogger = (event) => {
    return ({dataValues, _changed, $modelOptions}) => {
      if ((isTransaction($modelOptions) || allIgnoredFields(_changed))) {
        return;
      }

      const transactionData = Object.assign({event}, {
        object: $modelOptions.name.singular,
        objectId: dataValues.id,
        changedFields: Object.keys(_changed),
      });

      db.Transaction.create(transactionData).then((transaction) => {
        // PubsubConnector.notifyDelta(db.accountId, transaction.toJSON());
      })
    }
  }

  sequelize.addHook("afterCreate", transactionLogger("create"))
  sequelize.addHook("afterUpdate", transactionLogger("modify"))
  sequelize.addHook("afterDelete", transactionLogger("delete"))
}
