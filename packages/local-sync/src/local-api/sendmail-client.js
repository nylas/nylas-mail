/* eslint no-useless-escape: 0 */

const fs = require('fs');
const nodemailer = require('nodemailer');
const mailcomposer = require('mailcomposer');
const {HTTPError} = require('../shared/errors');

const MAX_RETRIES = 1;

const formatParticipants = (participants) => {
  return participants.map(p => `${p.name} <${p.email}>`).join(',');
}

class SendmailClient {
  constructor(account, logger) {
    this._transporter = nodemailer.createTransport(account.smtpConfig());
    this._logger = logger;
  }

  async _send(msgData) {
    let partialFailure;
    let error;
    for (let i = 0; i <= MAX_RETRIES; i++) {
      try {
        const results = await this._transporter.sendMail(msgData);
        const {rejected, pending} = results;
        if ((rejected && rejected.length > 0) || (pending && pending.length > 0)) {
          // At least one recipient was rejected by the server,
          // but at least one recipient got it. Don't retry; throw an
          // error so that we fail to client.
          partialFailure = new HTTPError(
            'Sending to at least one recipient failed', 200, results);
          throw partialFailure;
        } else {
          // Sending was successful!
          return
        }
      } catch (err) {
        error = err;
        if (err === partialFailure) {
          // We don't want to retry in this case, so re-throw the error
          throw err;
        }
        this._logger.error(err);
      }
    }
    this._logger.error('Max sending retries reached');
    this._handleError(error);
  }

  _handleError(err) {
    // TODO: figure out how to parse different errors, like in cloud-core
    // https://github.com/nylas/cloud-core/blob/production/sync-engine/inbox/sendmail/smtp/postel.py#L354

    if (err.message.startsWith("Error: Invalid login: 535-5.7.8 Username and Password not accepted.")) {
      throw new HTTPError('Invalid login', 401, err)
    }

    throw new HTTPError('Sending failed', 500, err);
  }

  _draftToMsgData(draft) {
    const msgData = {};
    for (const field of ['from', 'to', 'cc', 'bcc']) {
      if (draft[field]) {
        msgData[field] = formatParticipants(draft[field])
      }
    }
    msgData.date = draft.date;
    msgData.subject = draft.subject;
    msgData.html = draft.body;
    msgData.messageId = `${draft.id}@nylas.com`;

    msgData.attachments = []
    for (const upload of draft.uploads) {
      msgData.attachments.push({
        filename: upload.filename,
        content: fs.createReadStream(upload.targetPath),
        cid: upload.id,
      })
    }

    if (draft.replyTo) {
      msgData.replyTo = formatParticipants(draft.replyTo);
    }

    msgData.inReplyTo = draft.inReplyTo;
    msgData.references = draft.references;
    msgData.headers = draft.headers;
    msgData.headers['User-Agent'] = `NylasMailer-K2`

    return msgData;
  }

  _replaceBodyMessageIds(body, id) {
    const serverUrl = {
      local: 'http:\/\/lvh\.me:5100',
      development: 'http:\/\/lvh\.me:5100',
      staging: 'https:\/\/n1-staging\.nylas\.com',
      production: 'https:\/\/n1\.nylas\.com',
    }[process.env];
    const regex = new RegExp(`${serverUrl}.+MESSAGE_ID`, 'g')
    return body.replace(regex, (match) => {
      return match.replace('MESSAGE_ID', id)
    })
  }

  async buildMime(draft) {
    const builder = mailcomposer(this._draftToMsgData(draft))
    const mimeNode = await (new Promise((resolve, reject) => {
      builder.build((error, result) => {
        error ? reject(error) : resolve(result)
      })
    }));
    return mimeNode.toString('ascii')
  }

  async send(draft) {
    if (draft.isSent) {
      throw new Error(`Cannot send message ${draft.id}, it has already been sent`);
    }
    await this._send(this._draftToMsgData(draft));
    await (draft.isSent = true);
    await draft.save();
  }

  async sendCustomBody(draft, body, recipients) {
    const origBody = draft.body;
    draft.body = this._replaceBodyMessageIds(body);
    const envelope = {};
    for (const field of Object.keys(recipients)) {
      envelope[field] = recipients[field].map(r => r.email);
    }
    const raw = await this.buildMime(draft);
    const responseOnSuccess = draft.toJSON();
    draft.body = origBody;
    await this._send({raw, envelope});
    return responseOnSuccess;
  }
}

module.exports = SendmailClient;
