const Joi = require('joi');

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
  authPostConfig() {
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
}
