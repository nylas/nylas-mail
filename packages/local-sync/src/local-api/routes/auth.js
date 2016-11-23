const Joi = require('joi');
const _ = require('underscore');

const Serialization = require('../serialization');
const {
  IMAPConnection,
  IMAPErrors,
} = require('isomorphic-core');
const DefaultSyncPolicy = require('../default-sync-policy')
const LocalDatabaseConnector = require('../../shared/local-database-connector')
const SyncProcessManager = require('../../local-sync-worker/sync-process-manager')

const imapSmtpSettings = Joi.object().keys({
  imap_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
  imap_port: Joi.number().integer().required(),
  imap_username: Joi.string().required(),
  imap_password: Joi.string().required(),
  smtp_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
  smtp_port: Joi.number().integer().required(),
  smtp_username: Joi.string().required(),
  smtp_password: Joi.string().required(),
  ssl_required: Joi.boolean().required(),
}).required();

const gmailSettings = Joi.object().keys({
  google_client_id: Joi.string().required(),
  google_client_secret: Joi.string().required(),
  google_refresh_token: Joi.string().required(),
});

const exchangeSettings = Joi.object().keys({
  username: Joi.string().required(),
  password: Joi.string().required(),
  eas_server_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
}).required();

const buildAccountWith = ({name, email, provider, settings, credentials}) => {
  return LocalDatabaseConnector.forShared().then((db) => {
    const {AccountToken, Account} = db;

    return Account.find({
      where: {
        emailAddress: email,
        connectionSettings: JSON.stringify(settings),
      },
    }).then((existing) => {
      const account = existing || Account.build({
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
        AccountToken.create({accountId: saved.id}).then((token) =>
          LocalDatabaseConnector.ensureAccountDatabase(saved.id).then(() => {
            SyncProcessManager.addWorkerForAccount(saved);

            return Promise.resolve({
              account: saved,
              token: token,
            });
          })
        )
      );
    });
  });
}

module.exports = (server) => {
  server.route({
    method: 'POST',
    path: '/auth',
    config: {
      description: 'Authenticates a new account.',
      notes: 'Notes go here',
      tags: ['accounts'],
      auth: false,
      validate: {
        query: {
          client_id: Joi.string().required(),
          n1_id: Joi.string(),
        },
        payload: {
          email: Joi.string().email().required(),
          name: Joi.string().required(),
          provider: Joi.string().valid('imap', 'gmail').required(),
          settings: Joi.alternatives().try(imapSmtpSettings, exchangeSettings, gmailSettings),
        },
      },
      response: {
        schema: Joi.alternatives().try(
          Serialization.jsonSchema('Account'),
          Serialization.jsonSchema('Error')
        ),
      },
    },
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
          ssl_required: true,
        }
        connectionCredentials = {
          client_id: settings.google_client_id,
          client_secret: settings.google_client_secret,
          refresh_token: settings.google_refresh_token,
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
        response.token = token.value;
        reply(Serialization.jsonStringify(response));
      })
      .catch((err) => {
        const code = err instanceof IMAPErrors.IMAPAuthenticationError ? 401 : 400
        reply({message: err.message, type: "api_error"}).code(code);
      })
    },
  });
}
