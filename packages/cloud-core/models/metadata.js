const {JSONType} = require('../database-types');

module.exports = (sequelize, Sequelize) => {
  const Metadata = sequelize.define('metadata', {
    nylasId: Sequelize.STRING,
    accountId: Sequelize.STRING,
    modelId: Sequelize.STRING,
    key: Sequelize.STRING,
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
