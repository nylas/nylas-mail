const PubsubConnector = require('./pubsub-connector')

module.exports = (db, sequelize) => {
  const parseHookData = ({dataValues, _changed, $modelOptions}) => {
    return {
      object: $modelOptions.name.singular,
      objectId: dataValues.id,
      changedFields: _changed,
    }
  }

  const isSilent = (data) => {
    data._previousDataValues
    data._changed

    if (data.$modelOptions.name.singular === "transaction") {
      return true
    }

    if (data._changed && data._changed.syncState) {
      for (const key of Object.keys(data._changed)) {
        if (key === "syncState") { continue }
        if (data._changed[key] !== data._previousDataValues[key]) {
          // SyncState changed, but so did something else
          return false;
        }
      }
      // Be silent due to nothing but sync state changing
      return true;
    }
  }

  const transactionLogger = (type) => {
    return (sequelizeHookData) => {
      if (isSilent(sequelizeHookData)) return;

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
