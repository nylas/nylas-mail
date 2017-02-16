const {JSONArrayColumn} = require('../database-types');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('transaction', {
    event: Sequelize.STRING,
    object: Sequelize.STRING,
    objectId: Sequelize.STRING,
    accountId: Sequelize.STRING,
    changedFields: JSONArrayColumn('changedFields'),
  }, {
    indexes: [
      { fields: ['accountId'] },
    ],
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: `${this.id}`,
          event: this.event,
          object: this.object,
          objectId: `${this.objectId}`,
        }
      },
    },
  });
}
