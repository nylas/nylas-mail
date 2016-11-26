const {DatabaseTypes: {JSONType}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  const Metadata = sequelize.define('metadata', {
    nylasId: Sequelize.STRING,
    accountId: Sequelize.STRING,
    modelId: Sequelize.STRING,
    key: Sequelize.STRING,
    version: Sequelize.INTEGER,
    data: JSONType('data'),
  }, {
    classMethods: {
      associate: () => {
      },
    },
    instanceMethods: {
    },
  });

  return Metadata;
};
