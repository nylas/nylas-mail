const crypto = require('crypto');
const {JSONType, JSONARRAYType} = require('../../database-types');

let {DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD} = process.env;

module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('account', {
    name: Sequelize.STRING,
    provider: Sequelize.STRING,
    emailAddress: Sequelize.STRING,
    connectionSettings: JSONType('connectionSettings'),
    connectionCredentials: Sequelize.TEXT,
    syncPolicy: JSONType('syncPolicy'),
    syncError: JSONType('syncError', {defaultValue: null}),
    firstSyncCompletion: {
      type: Sequelize.STRING(14),
      allowNull: true,
      defaultValue: null,
    },
    lastSyncCompletions: JSONARRAYType('lastSyncCompletions'),
  }, {
    classMethods: {
      associate: ({AccountToken}) => {
        Account.hasMany(AccountToken, {as: 'tokens'})
      },
    },
    instanceMethods: {
      toJSON() {
        return {
          id: this.id,
          name: this.name,
          object: 'account',
          organization_unit: (this.provider === 'gmail') ? 'label' : 'folder',
          provider: this.provider,
          email_address: this.emailAddress,
          connection_settings: this.connectionSettings,
          sync_policy: this.syncPolicy,
          sync_error: this.syncError,
          first_sync_completion: this.firstSyncCompletion / 1,
          last_sync_completions: this.lastSyncCompletions,
          created_at: this.createdAt,
        }
      },

      errored() {
        return this.syncError != null;
      },

      setCredentials(json) {
        if (!(json instanceof Object)) {
          throw new Error("Call setCredentials with JSON!")
        }

        if (DB_ENCRYPTION_ALGORITHM && DB_ENCRYPTION_PASSWORD) {
          const cipher = crypto.createCipher(DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD)
          let crypted = cipher.update(JSON.stringify(json), 'utf8', 'hex')
          crypted += cipher.final('hex');
          this.connectionCredentials = crypted;
        } else {
          this.connectionCredentials = JSON.stringify(json);
        }
      },

      decryptedCredentials() {
        let dec = null;
        if (DB_ENCRYPTION_ALGORITHM && DB_ENCRYPTION_PASSWORD) {
          const decipher = crypto.createDecipher(DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD)
          dec = decipher.update(this.connectionCredentials, 'hex', 'utf8')
          dec += decipher.final('utf8');
        } else {
          dec = this.connectionCredentials;
        }

        try {
          return JSON.parse(dec);
        } catch (err) {
          return null;
        }
      },

      smtpConfig() {
        if (this.provider !== "imap") {
          throw new Error("Non IMAP not yet supported")
        }

        const {smtp_username, smtp_password} = this.decryptedCredentials();
        const {smtp_host, smtp_port, ssl_required} = this.connectionSettings;

        return {
          port: smtp_port, host: smtp_host, secure: ssl_required,
          auth: { user: smtp_username, pass: smtp_password},
        }
      },

      supportsLabels() {
        return this.provider === 'gmail'
      },
    },
  });

  return Account;
};
