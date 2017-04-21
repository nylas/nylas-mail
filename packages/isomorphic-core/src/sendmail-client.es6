/* eslint no-useless-escape: 0 */
import nodemailer from 'nodemailer'
import {APIError} from './errors'
import {convertSmtpError} from './smtp-errors'
import {getMailerPayload, buildMime} from './message-utils'

const MAX_RETRIES = 1;

class SendmailClient {

  constructor(account, logger) {
    this._smtpConfig = account.smtpConfig()
    this._transporter = nodemailer.createTransport(Object.assign(this._smtpConfig, {pool: true}));
    this._logger = logger;
  }

  async _send(msgData) {
    let error;
    let results;

    // disable nodemailer's automatic X-Mailer header
    msgData.xMailer = false;
    for (let i = 0; i <= MAX_RETRIES; i++) {
      try {
        results = await this._transporter.sendMail(msgData);
      } catch (err) {
        // Keep retrying for MAX_RETRIES
        error = convertSmtpError(err, this._smtpConfig);
        this._logger.error(err);
      }
      if (!results) {
        continue;
      }
      const {rejected, pending} = results;
      if ((rejected && rejected.length > 0) || (pending && pending.length > 0)) {
        // At least one recipient was rejected by the server,
        // but at least one recipient got it. Don't retry; throw an
        // error so that we fail to client.
        throw new APIError('Sending to at least one recipient failed', 402, {results});
      }
      return
    }
    this._logger.error('Max sending retries reached');

    let userMessage = 'Sending failed';
    let statusCode = 500;
    if (error && error.userMessage && error.statusCode) {
      userMessage = `Sending failed - ${error.userMessage}`;
      statusCode = error.statusCode;
    }

    const {host, port, secure} = this._transporter.transporter.options;
    throw new APIError(userMessage, statusCode, {
      originalError: error,
      smtp_host: host,
      smtp_port: port,
      smtp_use_ssl: secure,
    });
  }

  async send(message) {
    if (message.isSent) {
      throw new Error(`Cannot send message ${message.id}, it has already been sent`);
    }
    const payload = getMailerPayload(message)
    await this._send(payload);
  }

  async sendCustom(customMessage, recipients) {
    const envelope = {};
    for (const field of Object.keys(recipients)) {
      envelope[field] = recipients[field].map(r => r.email);
    }
    envelope.from = customMessage.from.map(c => c.email)
    const raw = await buildMime(customMessage);
    await this._send({raw, envelope});
  }
}

module.exports = SendmailClient;
