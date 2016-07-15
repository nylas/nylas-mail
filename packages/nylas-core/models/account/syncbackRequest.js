const {JSONType} = require('../../database-types');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('syncbackRequest', {
    type: Sequelize.STRING,
    status: {
      type: Sequelize.ENUM("NEW", "SUCCEEDED", "FAILED"),
      defaultValue: "NEW",
      allowNull: false,
    },
    error: JSONType('error'),
    props: JSONType('props'),
  });
};
