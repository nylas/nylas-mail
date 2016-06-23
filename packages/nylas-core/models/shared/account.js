const crypto = require('crypto');
const {JSONType} = require('../../database-types');

const algorithm = 'aes-256-ctr';
const password = 'd6F3Efeq';

module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('Account', {
    name: Sequelize.STRING,
    emailAddress: Sequelize.STRING,
    connectionSettings: JSONType('connectionSettings'),
    connectionCredentials: Sequelize.STRING,
    syncPolicy: JSONType('syncPolicy'),
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
          connection_settings: this.connectionSettings,
          sync_policy: this.syncPolicy,
        }
      },

      setCredentials: function setCredentials(json) {
        if (!(json instanceof Object)) {
          throw new Error("Call setCredentials with JSON!")
        }
        const cipher = crypto.createCipher(algorithm, password)
        let crypted = cipher.update(JSON.stringify(json), 'utf8', 'hex')
        crypted += cipher.final('hex');

        this.connectionCredentials = crypted;
      },

      decryptedCredentials: function decryptedCredentials() {
        const decipher = crypto.createDecipher(algorithm, password)
        let dec = decipher.update(this.connectionCredentials, 'hex', 'utf8')
        dec += decipher.final('utf8');

        try {
          return JSON.parse(dec);
        } catch (err) {
          return null;
        }
      },
    },
  });

  return Account;
};
