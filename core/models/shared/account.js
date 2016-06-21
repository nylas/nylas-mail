module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('Account', {
    emailAddress: Sequelize.STRING,
    syncPolicy: {
      type: Sequelize.STRING,
      get: function get() {
        return JSON.parse(this.getDataValue('syncPolicy'))
      },
      set: function set(val) {
        this.setDataValue('syncPolicy', JSON.stringify(val));
      },
    },
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
