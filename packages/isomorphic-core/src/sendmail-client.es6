/* eslint no-useless-escape: 0 */
import fs from 'fs'
import nodemailer from 'nodemailer'
import mailcomposer from 'mailcomposer'
import {APIError} from './errors'
import {convertSmtpError} from './smtp-errors'

const MAX_RETRIES = 1;

const formatParticipants = (participants) => {
  // Something weird happens with the mime building when the participant name
  // has an @ symbol in it (e.g. a name and email of hello@gmail.com turns into
  // 'hello@ <gmail.com hello@gmail.com>'), so replace it with whitespace.
  return participants.map(p => `${p.name.replace('@', ' ')} <${p.email}>`).join(',');
}

class SendmailClient {

  constructor(account, logger) {
    this._transporter = nodemailer.createTransport(Object.assign(account.smtpConfig(), {pool: true}));
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
        error = convertSmtpError(err);
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

  _getSendPayload(message) {
    const msgData = {};
    for (const field of ['from', 'to', 'cc', 'bcc']) {
      if (message[field]) {
        msgData[field] = formatParticipants(message[field])
      }
    }
    msgData.date = message.date;
    msgData.subject = message.subject;
    msgData.html = message.body;
    msgData.messageId = message.headerMessageId || message.message_id_header;

    msgData.attachments = []
    const uploads = message.uploads || []
    for (const upload of uploads) {
      msgData.attachments.push({
        filename: upload.filename,
        content: fs.createReadStream(upload.targetPath),
        cid: upload.inline ? upload.id : null,
      })
    }

    if (message.replyTo) {
      msgData.replyTo = formatParticipants(message.replyTo);
    }

    msgData.inReplyTo = message.inReplyTo;
    msgData.references = message.references;
    // message.headers is usually unset, but in the case that we do add
    // headers elsewhere, we don't want to override them here
    msgData.headers = message.headers || {};
    msgData.headers['User-Agent'] = `NylasMailer-K2`

    return msgData;
  }

  async buildMime(message) {
    const payload = this._getSendPayload(message)
    const builder = mailcomposer(payload)
    const mimeNode = await (new Promise((resolve, reject) => {
      builder.build((error, result) => (
        error ? reject(error) : resolve(result)
      ))
    }));
    return mimeNode.toString('ascii')
  }

  async send(message) {
    if (message.isSent) {
      throw new Error(`Cannot send message ${message.id}, it has already been sent`);
    }
    const payload = this._getSendPayload(message)
    await this._send(payload);
  }

  async sendCustom(customMessage, recipients) {
    const envelope = {};
    for (const field of Object.keys(recipients)) {
      envelope[field] = recipients[field].map(r => r.email);
    }
    envelope.from = customMessage.from.map(c => c.email)
    const raw = await this.buildMime(customMessage);
    await this._send({raw, envelope});
  }
}

module.exports = SendmailClient;
