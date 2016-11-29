const {DatabaseTypes: {JSONType}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  const Metadata = sequelize.define('metadata', {
    accountId: Sequelize.STRING,
    value: JSONType('data'),
    version: Sequelize.INTEGER,
    pluginId: Sequelize.STRING,
    objectId: Sequelize.STRING,
    objectType: Sequelize.STRING,
  }, {
    instanceMethods: {
      id: `${this.id}`,
      value: this.value,
      object: "metadata",
      version: this.version,
      plugin_id: this.pluginId,
      object_id: this.objectId,
      account_id: this.accountId,
      object_type: this.objectType,
    },
  });

  return Metadata;
};
