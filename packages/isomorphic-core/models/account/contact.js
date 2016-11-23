module.exports = (sequelize, Sequelize) => {
  return sequelize.define('contact', {
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    email: Sequelize.STRING,
  }, {
    indexes: [
      {
        unique: true,
        fields: ['email'],
      },
    ],
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: `${this.id}`,
          account_id: this.accountId,
          object: 'contact',
          email: this.email,
          name: this.name,
        }
      },
    },
  })
}
