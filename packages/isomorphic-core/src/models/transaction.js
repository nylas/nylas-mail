const {JSONArrayColumn} = require('../database-types');
const {MAX_INDEXABLE_LENGTH} = require('../db-utils');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('transaction', {
    event: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
    object: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
    objectId: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
    accountId: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
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
