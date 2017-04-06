const {DatabaseTypes: {JSONColumn},
       DBUtils: {MAX_INDEXABLE_LENGTH}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  const CloudJob = sequelize.define('CloudJob', {
    id: { type: Sequelize.INTEGER, primaryKey: true, autoIncrement: true },
    accountId: {type: Sequelize.STRING(MAX_INDEXABLE_LENGTH), allowNull: false},
    metadataId: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
    workerId: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
    foremanId: Sequelize.STRING(MAX_INDEXABLE_LENGTH),
    type: {type: Sequelize.STRING(MAX_INDEXABLE_LENGTH), allowNull: false},
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
