const {DatabaseTypes: {JSONColumn}} = require('isomorphic-core');

/**
 * CREATE TABLE IF NOT EXISTS `syncbackRequests` (
 *   `id` INTEGER PRIMARY KEY AUTOINCREMENT, `type` VARCHAR(255),
 *   `status` TEXT NOT NULL DEFAULT 'NEW',
 *   `error` TEXT,
 *   `props` TEXT,
 *   `responseJSON` TEXT,
 *   `accountId` VARCHAR(255) NOT NULL,
 *   `createdAt` DATETIME NOT NULL,
 *   `updatedAt` DATETIME NOT NULL
 * );
 */
module.exports = (sequelize, Sequelize) => {
  return sequelize.define('syncbackRequest', {
    type: Sequelize.STRING,
    status: {
      type: Sequelize.ENUM(
        "NEW",
        "INPROGRESS-RETRYABLE",
        "INPROGRESS-NOTRETRYABLE",
        "SUCCEEDED",
        "FAILED",
        "CANCELLED"
      ),
      defaultValue: "NEW",
      allowNull: false,
    },
    error: JSONColumn('error'),
    props: JSONColumn('props'),
    responseJSON: JSONColumn('responseJSON'),
    accountId: { type: Sequelize.STRING, allowNull: false },
  }, {
    indexes: [
      {fields: ['status', 'type']},
    ],
    instanceMethods: {
      toJSON() {
        return {
          id: `${this.id}`,
          type: this.type,
          error: this.error,
          props: this.props,
          response_json: this.responseJSON,
          status: this.status,
          object: 'syncbackRequest',
          account_id: this.accountId,
        }
      },
    },
  });
};
