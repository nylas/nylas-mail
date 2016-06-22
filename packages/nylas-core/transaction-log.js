const DeltaStreamQueue = require('./delta-stream-queue')

class TransactionLog {
  constructor(db) {
    this.db = db;
  }

  parseHookData({dataValues, _changed, $modelOptions}) {
    return {
      objectId: dataValues.id,
      modelName: $modelOptions.name.singular,
      changedFields: _changed,
    }
  }

  isTransaction({$modelOptions}) {
    return $modelOptions.name.singular === "Transaction"
  }

  transactionLogger(type) {
    return (sequelizeHookData) => {
      if (this.isTransaction(sequelizeHookData)) return;
      const transactionData = Object.assign({type: type},
        this.parseHookData(sequelizeHookData)
      );
      this.db.Transaction.create(transactionData);
      transactionData.object = sequelizeHookData.dataValues
      DeltaStreamQueue.notify(this.db.accountId, transactionData)
    }
  }

  setupSQLHooks(sequelize) {
    sequelize.addHook("afterCreate", this.transactionLogger("create"))
    sequelize.addHook("afterUpdate", this.transactionLogger("update"))
    sequelize.addHook("afterDelete", this.transactionLogger("delete"))
  }
}
module.exports = TransactionLog
