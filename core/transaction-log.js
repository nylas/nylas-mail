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
      this.db.Transaction.create(Object.assign({type: type},
        this.parseHookData(sequelizeHookData)
      ));
    }
  }

  setupSQLHooks(sequelize) {
    sequelize.addHook("afterCreate", this.transactionLogger("create"))
    sequelize.addHook("afterUpdate", this.transactionLogger("update"))
    sequelize.addHook("afterDelete", this.transactionLogger("delete"))
  }
}
module.exports = TransactionLog
