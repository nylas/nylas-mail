const Joi = require('Joi');
const _ = require('underscore');

const Serialization = require('../serialization');
const {IMAPConnection, DatabaseConnectionFactory} = require('nylas-core');

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

const exchangeSettings = Joi.object().keys({
  username: Joi.string().required(),
  password: Joi.string().required(),
  eas_server_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
}).required();

const defaultSyncPolicy = {
  afterSync: 'idle',
  interval: 30 * 1000,
  folderSyncOptions: {
    deepFolderScan: 5 * 60 * 1000,
  },
  expiration: Date.now() + 60 * 60 * 1000,
};

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
        },
        payload: {
          email: Joi.string().email().required(),
          name: Joi.string().required(),
          provider: Joi.string().required(),
          settings: Joi.alternatives().try(imapSmtpSettings, exchangeSettings),
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
      const connectionChecks = [];
      const {settings, email, provider, name} = request.payload;

      if (provider === 'imap') {
        const dbStub = {};
        const conn = new IMAPConnection(dbStub, settings);
        connectionChecks.push(conn.connect())
      }

      Promise.all(connectionChecks).then(() => {
        DatabaseConnectionFactory.forShared().then((db) => {
          const {AccountToken, Account} = db;

          const account = Account.build({
            name: name,
            emailAddress: email,
            syncPolicy: defaultSyncPolicy,
            connectionSettings: _.pick(settings, [
              'imap_host', 'imap_port',
              'smtp_host', 'smtp_port',
              'ssl_required',
            ]),
          })
          account.setCredentials(_.pick(settings, [
            'imap_username', 'imap_password',
            'smtp_username', 'smtp_password',
          ]));
          account.save().then((saved) =>
            AccountToken.create({
              AccountId: saved.id,
            }).then((accountToken) => {
              const response = saved.toJSON();
              response.token = accountToken.value;
              reply(Serialization.jsonStringify(response));
            })
          );
        })
      })
      .catch((err) => {
        // TODO: Lots more of this
        reply({error: err.toString()});
      })
    },
  });
};
