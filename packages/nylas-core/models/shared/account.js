const crypto = require('crypto');
const {JSONType} = require('../../database-types');

const {DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD} = process.env;

module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('account', {
    name: Sequelize.STRING,
    provider: Sequelize.STRING,
    emailAddress: Sequelize.STRING,
    connectionSettings: JSONType('connectionSettings'),
    connectionCredentials: Sequelize.STRING,
    syncPolicy: JSONType('syncPolicy'),
    syncError: JSONType('syncError', {defaultValue: null}),
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
          object: 'account',
          organization_unit: (this.provider === 'gmail') ? 'label' : 'folder',
          provider: this.provider,
          email_address: this.emailAddress,
          connection_settings: this.connectionSettings,
          sync_policy: this.syncPolicy,
          sync_error: this.syncError,
        }
      },

      errored: function errored() {
        return this.syncError != null
      },

      setCredentials: function setCredentials(json) {
        if (!(json instanceof Object)) {
          throw new NylasError("Call setCredentials with JSON!")
        }
        const cipher = crypto.createCipher(DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD)
        let crypted = cipher.update(JSON.stringify(json), 'utf8', 'hex')
        crypted += cipher.final('hex');

        this.connectionCredentials = crypted;
      },

      decryptedCredentials: function decryptedCredentials() {
        const decipher = crypto.createDecipher(DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD)
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
