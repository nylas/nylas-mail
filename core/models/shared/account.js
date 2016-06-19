module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('Account', {
    emailAddress: Sequelize.STRING,
  }, {
    classMethods: {
      associate: ({AccountToken}) => {
        Account.hasMany(AccountToken, {as: 'tokens'})
      },
    },
    instanceMethods: {
      toJSON: function toJSON() {
        return {
          id: this.id,
          email_address: this.emailAddress,
        }
      },
    },
  });

  return Account;
};
