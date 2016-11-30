const crypto = require('crypto');
const {buildJSONColumnOptions, buildJSONARRAYColumnOptions} = require('../database-types');

const {DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD} = process.env;

module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('account', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    name: Sequelize.STRING,
    provider: Sequelize.STRING,
    emailAddress: Sequelize.STRING,
    connectionSettings: buildJSONColumnOptions('connectionSettings'),
    connectionCredentials: Sequelize.TEXT,
    syncPolicy: buildJSONColumnOptions('syncPolicy'),
    syncError: buildJSONColumnOptions('syncError', {defaultValue: null}),
    firstSyncCompletion: {
      type: Sequelize.STRING(14),
      allowNull: true,
      defaultValue: null,
    },
    lastSyncCompletions: buildJSONARRAYColumnOptions('lastSyncCompletions'),
  }, {
    indexes: [
      {
        unique: true,
        fields: ['id'],
      },
    ],
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
        const {smtp_host, smtp_port, ssl_required} = this.connectionSettings;
        const config = {
          host: smtp_host,
          port: smtp_port,
          secure: ssl_required,
        }

        if (this.provider === "imap") {
          const {smtp_username, smtp_password} = this.decryptedCredentials();
          config.auth = { user: smtp_username, pass: smtp_password}
        } else if (this.provider === 'gmail') {
          const {xoauth2} = this.decryptedCredentials();
          const {imap_username} = this.connectionSettings;

          // We have to unpack the access token from the entire XOAuth2
          // token because it is re-packed during the SMTP connection login.
          // https://github.com/nodemailer/smtp-connection/blob/master/lib/smtp-connection.js#L1418
          const bearer = "Bearer ";
          const decoded = atob(xoauth2);
          const tokenIndex = decoded.indexOf(bearer) + bearer.length;
          const token = decoded.substring(tokenIndex, decoded.length - 2);

          config.auth = { user: imap_username, xoauth2: token }
        } else {
          throw new Error(`${this.provider} not yet supported`)
        }

        return config;
      },

      supportsLabels() {
        return this.provider === 'gmail'
      },
    },
  });

  return Account;
};
