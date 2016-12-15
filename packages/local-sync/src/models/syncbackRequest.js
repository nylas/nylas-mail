const {DatabaseTypes: {JSONColumn}} = require('isomorphic-core');

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('syncbackRequest', {
    type: Sequelize.STRING,
    status: {
      type: Sequelize.ENUM("NEW", "SUCCEEDED", "FAILED"),
      defaultValue: "NEW",
      allowNull: false,
    },
    error: JSONColumn('error'),
    props: JSONColumn('props'),
    responseJSON: JSONColumn('responseJSON'),
    accountId: { type: Sequelize.STRING, allowNull: false },
  }, {
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
