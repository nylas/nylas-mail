const {DatabaseTypes: {JSONColumn}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  const CloudJob = sequelize.define('CloudJob', {
    id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
    accountId: {type: Sequelize.STRING, allowNull: false},
    metadataId: Sequelize.STRING,
    workerId: Sequelize.STRING,
    foremanId: Sequelize.STRING,
    type: {type: Sequelize.STRING, allowNull: false},
    claimedAt: Sequelize.DATE,
    statusUpdatedAt: Sequelize.DATE,
    attemptNumber: {type: Sequelize.INTEGER, defaultValue: 0, allowNull: false},
    retryAt: Sequelize.DATE,
    status: {
      type: Sequelize.ENUM(
        "NEW",
        "INPROGRESS-RETRYABLE",
        "INPROGRESS-NOTRETRYABLE",
        "SUCCEEDED",
        "FAILED",
        "WAITING-TO-RETRY",
        "CANCELLED"
      ),
      defaultValue: "NEW",
      allowNull: false,
    },
    error: JSONColumn('error'),
  }, {
    indexes: [
      { fields: ['type'] },
      { fields: ['foremanId'] },
      { fields: ['status'] },
      { fields: ['statusUpdatedAt'] },
      { fields: ['attemptNumber'] },
    ],
  });

  return CloudJob;
};
