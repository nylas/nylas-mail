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
  smtp_custom_config: Joi.object(),
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

const SUPPORTED_PROVIDERS = new Set(
  ['gmail', 'office365', 'imap', 'icloud', 'yahoo', 'fastmail']
);

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
  } else if (provider === "office365") {
    const connectionSettings = {
      imap_host: 'outlook.office365.com',
      imap_port: 993,
      ssl_required: true,
      smtp_custom_config: {
        host: 'smtp.office365.com',
        port: 587,
        secure: false,
        tls: {ciphers: 'SSLv3'},
      },
    }

    const connectionCredentials = {
      imap_username: email,
      imap_password: settings.password,
      smtp_username: email,
      smtp_password: settings.password,
    }
    return {connectionSettings, connectionCredentials}
  } else if (SUPPORTED_PROVIDERS.has(provider)) {
    const connectionSettings = _.pick(settings, [
      'imap_host', 'imap_port',
      'smtp_host', 'smtp_port',
      'ssl_required', 'smtp_custom_config',
    ]);
    const connectionCredentials = _.pick(settings, [
      'imap_username', 'imap_password',
      'smtp_username', 'smtp_password',
    ]);
    return {connectionSettings, connectionCredentials}
  }
  throw new Error(`Invalid provider: ${provider}`)
}

module.exports = {
  SUPPORTED_PROVIDERS,
  imapAuthRouteConfig() {
    return {
      description: 'Authenticates a new account.',
      tags: ['accounts'],
      auth: false,
      validate: {
        payload: {
          email: Joi.string().email().required(),
          name: Joi.string().required(),
          provider: Joi.string().valid(...SUPPORTED_PROVIDERS).required(),
          settings: Joi.alternatives().try(imapSmtpSettings, office365Settings, resolvedGmailSettings),
        },
      },
    }
  },

  imapAuthHandler(upsertAccount) {
    const MAX_RETRIES = 2
    const authHandler = (request, reply, retryNum = 0) => {
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
        reply(JSON.stringify(response));
        return
      })
      .catch((err) => {
        if (err instanceof IMAPErrors.IMAPAuthenticationError) {
          global.Logger.error({err}, 'Encountered authentication error while attempting to authenticate')
          reply({message: USER_ERRORS.IMAP_AUTH, type: "api_error"}).code(401);
          return
        }
        if (err instanceof IMAPErrors.RetryableError) {
          if (retryNum < MAX_RETRIES) {
            setTimeout(() => {
              request.logger.info(`IMAP Timeout. Retry #${retryNum + 1}`)
              authHandler(request, reply, retryNum + 1)
            }, 100)
            return
          }
          global.Logger.error({err}, 'Encountered retryable error while attempting to authenticate')
          reply({message: USER_ERRORS.IMAP_RETRY, type: "api_error"}).code(408);
          return
        }
        global.Logger.error({err}, 'Encountered unknown error while attempting to authenticate')
        reply({message: USER_ERRORS.AUTH_500, type: "api_error"}).code(500);
        return
      })
    }
    return authHandler
  },
}
