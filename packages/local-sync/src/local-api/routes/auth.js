const Joi = require('joi');
const _ = require('underscore');
const crypto = require('crypto');
const Serialization = require('../serialization');
const {
  IMAPErrors,
  AuthHelpers,
  IMAPConnection,
} = require('isomorphic-core');
const DefaultSyncPolicy = require('../default-sync-policy')
const LocalDatabaseConnector = require('../../shared/local-database-connector')
const SyncProcessManager = require('../../local-sync-worker/sync-process-manager')

const buildAccountWith = ({name, email, provider, settings, credentials}) => {
  return LocalDatabaseConnector.forShared().then((db) => {
    const {AccountToken, Account} = db;

    const idString = `${email}${JSON.stringify(settings)}`
    const id = crypto.createHash('sha256').update(idString, 'utf8').digest('hex')
    return Account.findById(id).then((existing) => {
      const account = existing || Account.build({
        id,
        name: name,
        provider: provider,
        emailAddress: email,
        connectionSettings: settings,
        syncPolicy: DefaultSyncPolicy,
        lastSyncCompletions: [],
      })

      // always update with the latest credentials
      account.setCredentials(credentials);

      return account.save().then((saved) =>
        AccountToken.create({accountId: saved.id}).then((token) => {
          SyncProcessManager.addWorkerForAccount(saved);
          return Promise.resolve({
            account: saved,
            token: token,
          });
        })
      );
    });
  });
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/auth',
    config: AuthHelpers.authPostConfig(),
    handler: (request, reply) => {
      const dbStub = {};
      const connectionChecks = [];
      const {settings, email, provider, name} = request.payload;

      let connectionSettings = null;
      let connectionCredentials = null;

      if (provider === 'imap') {
        connectionSettings = _.pick(settings, [
          'imap_host', 'imap_port',
          'smtp_host', 'smtp_port',
          'ssl_required',
        ]);
        connectionCredentials = _.pick(settings, [
          'imap_username', 'imap_password',
          'smtp_username', 'smtp_password',
        ]);
      }

      if (provider === 'gmail') {
        connectionSettings = {
          imap_username: email,
          imap_host: 'imap.gmail.com',
          imap_port: 993,
          smtp_username: email,
          smtp_host: 'smtp.gmail.com',
          smtp_port: 465,
          ssl_required: true,
        }
        connectionCredentials = {
          xoauth2: settings.xoauth2,
        }
      }

      connectionChecks.push(IMAPConnection.connect({
        settings: Object.assign({}, connectionSettings, connectionCredentials),
        logger: request.logger,
        db: dbStub,
      }));

      Promise.all(connectionChecks).then((conns) => {
        for (const conn of conns) {
          if (conn) { conn.end(); }
        }
        return buildAccountWith({
          name: name,
          email: email,
          provider: provider,
          settings: connectionSettings,
          credentials: connectionCredentials,
        })
      })
      .then(({account, token}) => {
        const response = account.toJSON();
        response.auth_token = token.value;
        reply(Serialization.jsonStringify(response));
      })
      .catch((err) => {
        const code = err instanceof IMAPErrors.IMAPAuthenticationError ? 401 : 400
        reply({message: err.message, type: "api_error"}).code(code);
      })
    },
  });
}
