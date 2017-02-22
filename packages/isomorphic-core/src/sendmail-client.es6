/* eslint no-useless-escape: 0 */
const fs = require('fs');
const nodemailer = require('nodemailer');
const mailcomposer = require('mailcomposer');
const {APIError} = require('./errors')

const MAX_RETRIES = 1;

const formatParticipants = (participants) => {
  return participants.map(p => `${p.name} <${p.email}>`).join(',');
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
        // TODO: shouldn't retry on permanent errors like Invalid login
        // TODO: should also wait between retries :(
        // Keep retrying for MAX_RETRIES
        error = err;
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

    // TODO: figure out how to parse different errors, like in cloud-core
    // https://github.com/nylas/cloud-core/blob/production/sync-engine/inbox/sendmail/smtp/postel.py#L354
    if (/invalid login/i.test(error.message)) {
      throw new APIError(`Sending failed - Invalid login`, 401, {originalError: error})
    }

    if (error.message.includes("getaddrinfo ENOTFOUND")) {
      throw new APIError(`Sending failed - Network Error`, 401, {originalError: error})
    }

    if (error.message.includes("connect ETIMEDOUT")) {
      throw new APIError('Sending failed - Network Error', 401, {originalError: error})
    }

    throw new APIError('Sending failed', 500, {originalError: error});
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
    msgData.messageId = message.headerMessageId;

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
