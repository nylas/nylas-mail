const crypto = require('crypto')

module.exports = (sequelize, Sequelize) => {
  return sequelize.define('contact', {
    id: {type: Sequelize.STRING(65), primaryKey: true},
    accountId: { type: Sequelize.STRING, allowNull: false },
    version: Sequelize.INTEGER,
    name: Sequelize.STRING,
    email: Sequelize.STRING,
  }, {
    indexes: [
      {
        unique: true,
        fields: ['id'],
      },
    ],
    classMethods: {
      hash({email}) {
        return crypto.createHash('sha256').update(email, 'utf8').digest('hex');
      },
    },
    instanceMethods: {
      toJSON() {
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
