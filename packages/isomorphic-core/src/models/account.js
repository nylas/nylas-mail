const crypto = require('crypto');

const {JSONColumn, JSONArrayColumn} = require('../database-types');
const {credentialsForProvider, smtpConfigFromSettings} = require('../auth-helpers');


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

      smtpConfig() {
        // We always call credentialsForProvider() here because n1Cloud
        // sometimes needs to send emails for accounts which did not have their
        // full SMTP settings saved to the database.
        const {connectionSettings, connectionCredentials} = credentialsForProvider({
          provider: this.provider,
          settings: Object.assign({}, this.decryptedCredentials(), this.connectionSettings),
          email: this.emailAddress,
        });
        return smtpConfigFromSettings(this.provider, connectionSettings, connectionCredentials);
      },
    },
  });

  return Account;
};
