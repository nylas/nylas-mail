const {JSONARRAYType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  const Transaction = sequelize.define('transaction', {
    event: Sequelize.STRING,
    object: Sequelize.STRING,
    objectId: Sequelize.STRING,
    changedFields: JSONARRAYType('changedFields'),
  }, {
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: this.id,
          event: this.event,
          object: this.object,
          objectId: this.objectId,
          changedFields: this.changedFields,
        }
      },
    },
  })

  return Transaction;
};
