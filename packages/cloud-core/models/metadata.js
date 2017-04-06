const _ = require('underscore')
const {DatabaseTypes: {JSONColumn}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  const Metadata = sequelize.define('metadata', {
    id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
    accountId: Sequelize.STRING,
    value: JSONColumn('value', { columnType: Sequelize.LONGTEXT }),
    version: Sequelize.INTEGER,
    pluginId: Sequelize.STRING,
    objectId: Sequelize.STRING,
    objectType: Sequelize.STRING,
    expiration: Sequelize.DATE,
  }, {
    indexes: [
      { fields: ['objectId', 'objectType'] },
      { fields: ['expiration'] },
      { fields: ['pluginId'] },
    ],
    instanceMethods: {
      toJSON() {
        return {
          id: `${this.id}`,
          value: this.value,
          object: "metadata",
          version: this.version,
          plugin_id: this.pluginId,
          object_id: this.objectId,
          account_id: this.accountId,
          object_type: this.objectType,
        };
      },
      updateValue(value, {transaction} = {}) {
        if (!_.isObject(this.value)) {
          throw new Error(`Metadata.updateValue: \`value\` must be defined`)
        }
        this.value = Object.assign({}, this.value, value)
        if (transaction) {
          return this.save({transaction})
        }
        return sequelize.transaction((t) => {
          return this.save({transaction: t})
        })
      },
      async clearExpiration({transaction} = {}) {
        if (!_.isObject(this.value)) {
          throw new Error(`Metadata.clearExpiration: Can't clear expiration without a \`value\``)
        }
        // We need to update the `expiration` column, but also the `expiration`
        // field inside our json `value` so that we generate the correct deltas
        // for Nylas Mail
        this.value = Object.assign({}, this.value, {expiration: null})
        this.expiration = null
        await this.save({transaction})
      },
    },
  });

  return Metadata;
};
