const {DatabaseTypes: {JSONColumn}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  const Metadata = sequelize.define('metadata', {
    accountId: Sequelize.STRING,
    value: JSONColumn('value'),
    version: Sequelize.INTEGER,
    pluginId: Sequelize.STRING,
    objectId: Sequelize.STRING,
    objectType: Sequelize.STRING,
    expiration: Sequelize.DATE,
  }, {
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
      updateValue(value) {
        this.value = Object.assign({}, this.value, value)
        return sequelize.transaction((t) => {
          return this.save({transaction: t})
        })
      },
    },
  });

  return Metadata;
};
