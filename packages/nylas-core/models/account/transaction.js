module.exports = (sequelize, Sequelize) => {
  const Transaction = sequelize.define('transaction', {
    type: Sequelize.STRING,
    objectId: Sequelize.STRING,
    modelName: Sequelize.STRING,
    changedFields: {
      type: Sequelize.STRING,
      get: function get() {
        return JSON.parse(this.getDataValue('changedFields'))
      },
      set: function set(val) {
        this.setDataValue('changedFields', JSON.stringify(val));
      },
    },
  });

  return Transaction;
};
