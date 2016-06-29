const {typeJSON} = require('../model-helpers')

module.exports = (sequelize, Sequelize) => {
  const SyncbackRequest = sequelize.define('syncbackRequest', {
    type: Sequelize.STRING,
    status: {
      type: Sequelize.ENUM("NEW", "SUCCEEDED", "FAILED"),
      defaultValue: "NEW",
      allowNull: false,
    },
    error: typeJSON('error'),
    props: typeJSON('props'),
  });

  return SyncbackRequest;
};
