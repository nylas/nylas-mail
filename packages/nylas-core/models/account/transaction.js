const {JSONARRAYType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Transaction = sequelize.define('transaction', {
    event: Sequelize.STRING,
    object: Sequelize.STRING,
    objectId: Sequelize.STRING,
    changedFields: JSONARRAYType('changedFields'),
  });

  return Transaction;
};
