const atob = require('atob')
const crypto = require('crypto');
const {JSONColumn, JSONArrayColumn} = require('../database-types');
const {SUPPORTED_PROVIDERS} = require('../auth-helpers');

const {DB_ENCRYPTION_ALGORITHM, DB_ENCRYPTION_PASSWORD} = process.env;

module.exports = (sequelize, Sequelize) => {
  const Account = sequelize.define('account', {
    id: { type: Sequelize.STRING(65), primaryKey: true },
    name: Sequelize.STRING,
    provider: Sequelize.STRING,
    emailAddress: Sequelize.STRING,
    connectionSettings: JSONColumn('connectionSettings'),
    connectionCredentials: Sequelize.TEXT,
    syncPolicy: JSONColumn('syncPolicy'),
    syncError: JSONColumn('syncError'),
    firstSyncCompletion: {
      type: Sequelize.STRING(14),
      allowNull: true,
      defaultValue: null,
    },
    lastSyncCompletions: JSONArrayColumn('lastSyncCompletions'),
  }, {
    indexes: [
      {
        unique: true,
        fields: ['id'],
      },
    ],
    classMethods: {
      associate(data = {}) {
        Account.hasMany(data.AccountToken, {as: 'tokens', onDelete: 'cascade', hooks: true})
      },
      upsertWithCredentials(accountParams, credentials) {
        if (!accountParams || !credentials || !accountParams.emailAddress) {
          throw new Error("Need to pass accountParams and credentials to upsertWithCredentials")
        }
        const idString = `${accountParams.emailAddress}${JSON.stringify(accountParams.connectionSettings)}`;
        const id = crypto.createHash('sha256').update(idString, 'utf8').digest('hex')
        return Account.findById(id).then((existing) => {
          const account = existing || Account.build(Object.assign({id}, accountParams))

          // always update with the latest credentials
          account.setCredentials(credentials);

          return account.save().then((saved) => {
            return sequelize.models.accountToken.create({accountId: saved.id}).then((token) => {
              return Promise.resolve({account: saved, token: token})
            })
          });
        });
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

      bearerToken(xoauth2) {
        // We have to unpack the access token from the entire XOAuth2
        // token because it is re-packed during the SMTP connection login.
        // https://github.com/nodemailer/smtp-connection/blob/master/lib/smtp-connection.js#L1418
        const bearer = "Bearer ";
        const decoded = atob(xoauth2);
        const tokenIndex = decoded.indexOf(bearer) + bearer.length;
        return decoded.substring(tokenIndex, decoded.length - 2);
      },

      smtpConfig() {
        const {smtp_host, smtp_port, ssl_required} = this.connectionSettings;
        let config = {}
        if (this.connectionSettings.smtp_custom_config) {
          config = this.connectionSettings.smtp_custom_config
        } else {
          config = {
            host: smtp_host,
            port: smtp_port,
            secure: ssl_required,
          }
        }
        if (this.provider === 'gmail') {
          const {xoauth2} = this.decryptedCredentials();
          if (!xoauth2) {
            throw new Error("Missing XOAuth2 Token")
          }
          const {imap_username} = this.connectionSettings;
          const token = this.bearerToken(xoauth2);
          config.auth = { user: imap_username, xoauth2: token }
        } else if (SUPPORTED_PROVIDERS.has(this.provider)) {
          const {smtp_username, smtp_password} = this.decryptedCredentials();
          config.auth = { user: smtp_username, pass: smtp_password}
        } else {
          throw new Error(`${this.provider} not yet supported`)
        }

        return config;
      },
    },
  });

  return Account;
};
