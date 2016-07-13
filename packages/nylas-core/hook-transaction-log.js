const _ = require('underscore')
const PubsubConnector = require('./pubsub-connector')

module.exports = (db, sequelize) => {
  const parseHookData = ({dataValues, _changed, $modelOptions}) => {
    return {
      object: $modelOptions.name.singular,
      objectId: dataValues.id,
      changedFields: Object.keys(_changed),
    }
  }

  const isTransaction = (data) => {
    return data.$modelOptions.name.singular === "transaction"
  }

  const allIgnoredFields = (data) => {
    const IGNORED_FIELDS = ["syncState", "version"];
    return _.difference(Object.keys(data._changed), IGNORED_FIELDS).length === 0
  }

  const isIgnored = (data) => {
    return (isTransaction(data) || allIgnoredFields(data))
  }

  const transactionLogger = (type) => {
    return (sequelizeHookData) => {
      if (isIgnored(sequelizeHookData)) return;

      const event = (type === "update" ? "modify" : type)
      const transactionData = Object.assign({event},
        parseHookData(sequelizeHookData)
      );
      db.Transaction.create(transactionData).then((transaction) => {
        const dataValues = transaction.dataValues
        dataValues.attributes = sequelizeHookData.dataValues;
        dataValues.cursor = transaction.id;
        PubsubConnector.notifyDelta(db.accountId, dataValues);
      })

    }
  }

  sequelize.addHook("afterCreate", transactionLogger("create"))
  sequelize.addHook("afterUpdate", transactionLogger("update"))
  sequelize.addHook("afterDelete", transactionLogger("delete"))
}
