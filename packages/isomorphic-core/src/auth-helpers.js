const _ = require('underscore')
const Joi = require('joi');
const IMAPErrors = require('./imap-errors')
const IMAPConnection = require('./imap-connection')

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

const resolvedGmailSettings = Joi.object().keys({
  xoauth2: Joi.string().required(),
}).required();

const exchangeSettings = Joi.object().keys({
  username: Joi.string().required(),
  password: Joi.string().required(),
  eas_server_host: [Joi.string().ip().required(), Joi.string().hostname().required()],
}).required();

module.exports = {
  imapAuthRouteConfig() {
    return {
      description: 'Authenticates a new account.',
      tags: ['accounts'],
      auth: false,
      validate: {
        payload: {
          email: Joi.string().email().required(),
          name: Joi.string().required(),
          provider: Joi.string().valid('imap', 'gmail').required(),
          settings: Joi.alternatives().try(imapSmtpSettings, exchangeSettings, resolvedGmailSettings),
        },
      },
    }
  },

  imapAuthHandler(accountBuildFn) {
    return (request, reply) => {
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
        const accountParams = {
          name: name,
          provider: provider,
          emailAddress: email,
          connectionSettings: connectionSettings,
        }
        return accountBuildFn(accountParams, connectionCredentials)
      })
      .then(({account, token}) => {
        const response = account.toJSON();
        response.account_token = token.value;
        reply(JSON.stringify(response));
      })
      .catch((err) => {
        const code = err instanceof IMAPErrors.IMAPAuthenticationError ? 401 : 400
        reply({message: err.message, type: "api_error"}).code(code);
      })
    }
  },
}
