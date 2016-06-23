const Joi = require('Joi');
const _ = require('underscore');

const Serialization = require('../serialization');
const {
  IMAPConnection,
  PubsubConnector,
  DatabaseConnector,
  SyncPolicy
} = require('nylas-core');

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
        DatabaseConnector.forShared().then((db) => {
          const {AccountToken, Account} = db;

          const account = Account.build({
            name: name,
            emailAddress: email,
            syncPolicy: SyncPolicy.defaultPolicy(),
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
              const client = PubsubConnector.broadcastClient();
              client.lpushAsync('accounts:unclaimed', saved.id).catch((err) => {
                console.error(`Auth: Could not queue account sync! ${err.message}`)
              });

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
