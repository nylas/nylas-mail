const {JSONARRAYType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Transaction = sequelize.define('transaction', {
    type: Sequelize.STRING,
    objectId: Sequelize.STRING,
    modelName: Sequelize.STRING,
    changedFields: JSONARRAYType('changedFields'),
  });

  return Transaction;
};
