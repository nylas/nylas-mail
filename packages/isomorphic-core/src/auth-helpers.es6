import _ from 'underscore'
import Joi from 'joi'
import atob from 'atob';
import nodemailer from 'nodemailer';
import IMAPConnection from './imap-connection'
import {NylasError, RetryableError} from './errors'
import {convertSmtpError} from './smtp-errors'

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

export const SUPPORTED_PROVIDERS = new Set(
  ['gmail', 'office365', 'imap', 'icloud', 'yahoo', 'fastmail']
);

export function credentialsForProvider({provider, settings, email}) {
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
      imap_password: settings.password || settings.imap_password,
      smtp_username: email,
      smtp_password: settings.password || settings.smtp_password,
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

function bearerToken(xoauth2) {
  // We have to unpack the access token from the entire XOAuth2
  // token because it is re-packed during the SMTP connection login.
  // https://github.com/nodemailer/smtp-connection/blob/master/lib/smtp-connection.js#L1418
  const bearer = "Bearer ";
  const decoded = atob(xoauth2);
  const tokenIndex = decoded.indexOf(bearer) + bearer.length;
  return decoded.substring(tokenIndex, decoded.length - 2);
}

export function smtpConfigFromSettings(provider, connectionSettings, connectionCredentials) {
  let config;
  const {smtp_host, smtp_port, ssl_required} = connectionSettings;
  if (connectionSettings.smtp_custom_config) {
    config = connectionSettings.smtp_custom_config;
  } else {
    config = {
      host: smtp_host,
      port: smtp_port,
      secure: ssl_required,
    };
  }

  if (provider === 'gmail') {
    const {xoauth2} = connectionCredentials;
    if (!xoauth2) {
      throw new Error("Missing XOAuth2 Token")
    }

    const token = bearerToken(xoauth2);
    config.auth = { user: connectionSettings.smtp_username, xoauth2: token }
  } else if (SUPPORTED_PROVIDERS.has(provider)) {
    const {smtp_username, smtp_password} = connectionCredentials
    config.auth = { user: smtp_username, pass: smtp_password}
  } else {
    throw new Error(`${provider} not yet supported`)
  }

  return config;
}

export function imapAuthRouteConfig() {
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
}

export function imapAuthHandler(upsertAccount) {
  const MAX_RETRIES = 2
  const authHandler = (request, reply, retryNum = 0) => {
    const dbStub = {};
    const {email, provider, name} = request.payload;

    const connectionChecks = [];
    const {connectionSettings, connectionCredentials} = credentialsForProvider(request.payload)

    // All IMAP accounts require a valid SMTP server for sending, and we never
    // want to allow folks to connect accounts and find out later that they
    // entered the wrong SMTP credentials. So verify here also!
    const smtpConfig = smtpConfigFromSettings(provider, connectionSettings, connectionCredentials);
    const smtpTransport = nodemailer.createTransport(Object.assign({
      connectionTimeout: 30000,
    }, smtpConfig));
    const smtpVerifyPromise = smtpTransport.verify().catch((error) => {
      throw convertSmtpError(error);
    })

    connectionChecks.push(smtpVerifyPromise);
    connectionChecks.push(IMAPConnection.connect({
      settings: Object.assign({}, connectionSettings, connectionCredentials),
      logger: request.logger,
      db: dbStub,
    }));

    Promise.all(connectionChecks).then((results) => {
      for (const result of results) {
        // close any IMAP connections we opened
        if (result && result.end) { result.end(); }
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
        const logger = request.logger.child({
          account_name: name,
          account_provider: provider,
          account_email: email,
          connection_settings: connectionSettings,
          error_name: err.name,
          error_message: err.message,
          error_tb: err.stack,
        })

        if (err instanceof RetryableError) {
          if (retryNum < MAX_RETRIES) {
            setTimeout(() => {
              request.logger.info(`${err.name}. Retry #${retryNum + 1}`)
              authHandler(request, reply, retryNum + 1)
            }, 100)
            return
          }
          logger.error('Encountered retryable error while attempting to authenticate')
          reply({message: err.userMessage, type: "api_error"}).code(err.statusCode);
          return
        }

        logger.error("Error trying to authenticate")
        let userMessage = "Please contact support@nylas.com. An unforeseen error has occurred.";
        let statusCode = 500;
        if (err instanceof NylasError) {
          if (err.userMessage) {
            userMessage = err.userMessage;
          }
          if (err.statusCode) {
            statusCode = err.statusCode;
          }
        }
        reply({message: userMessage, type: "api_error"}).code(statusCode);
        return;
      })
  }
  return authHandler
}
