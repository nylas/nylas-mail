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
  expiry_date: Joi.number().integer().required(),
}).required();

const office365Settings = Joi.object().keys({
  name: Joi.string().required(),
  type: Joi.string().valid('office365').required(),
  email: Joi.string().required(),
  password: Joi.string().required(),
  username: Joi.string().required(),
}).required();

const USER_ERRORS = {
  AUTH_500: "Please contact support@nylas.com. An unforeseen error has occurred.",
  IMAP_AUTH: "Incorrect username or password",
  IMAP_RETRY: "We were unable to reach your mail provider. Please try again.",
}

function credentialsForProvider({provider, settings, email}) {
  if (provider === "gmail") {
    const connectionSettings = {
      imap_username: email,
      imap_host: 'imap.gmail.com',
      imap_port: 993,
      smtp_username: email,
      smtp_host: 'smtp.gmail.com',
      smtp_port: 465,
      ssl_required: true,
    }
    const connectionCredentials = {
      xoauth2: settings.xoauth2,
      expiry_date: settings.expiry_date,
    }
    return {connectionSettings, connectionCredentials}
  } else if (provider === "imap") {
    const connectionSettings = _.pick(settings, [
      'imap_host', 'imap_port',
      'smtp_host', 'smtp_port',
      'ssl_required',
    ]);
    const connectionCredentials = _.pick(settings, [
      'imap_username', 'imap_password',
      'smtp_username', 'smtp_password',
    ]);
    return {connectionSettings, connectionCredentials}
  } else if (provider === "office365") {
    const connectionSettings = {
      imap_host: 'outlook.office365.com',
      imap_port: 993,
      smtp_host: 'smtp.office365.com',
      smtp_port: 465,
      ssl_required: true,
    }
    const connectionCredentials = {
      imap_username: email,
      imap_password: settings.password,
      smtp_username: email,
      smpt_password: settings.password,
    }
    return {connectionSettings, connectionCredentials}
  }
  throw new Error(`Invalid provider: ${provider}`)
}

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
          provider: Joi.string().valid('imap', 'gmail', 'office365').required(),
          settings: Joi.alternatives().try(imapSmtpSettings, office365Settings, resolvedGmailSettings),
        },
      },
    }
  },

  imapAuthHandler(upsertAccount) {
    return (request, reply) => {
      const dbStub = {};
      const connectionChecks = [];
      const {email, provider, name} = request.payload;

      const {connectionSettings, connectionCredentials} = credentialsForProvider(request.payload)

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
        return upsertAccount(accountParams, connectionCredentials)
      })
      .then(({account, token}) => {
        const response = account.toJSON();
        response.account_token = token.value;
        return reply(JSON.stringify(response));
      })
      .catch((err) => {
        request.logger.error(err)
        if (err instanceof IMAPErrors.IMAPAuthenticationError) {
          return reply({message: USER_ERRORS.IMAP_AUTH, type: "api_error"}).code(401);
        }
        if (err instanceof IMAPErrors.RetryableError) {
          return reply({message: USER_ERRORS.IMAP_RETRY, type: "api_error"}).code(408);
        }
        return reply({message: USER_ERRORS.AUTH_500, type: "api_error"}).code(500);
      })
    }
  },
}
