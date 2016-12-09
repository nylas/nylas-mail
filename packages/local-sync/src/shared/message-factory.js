const _ = require('underscore');
const cryptography = require('crypto');
const utf7 = require('utf7').imap;
const mimelib = require('mimelib');
const QuotedPrintable = require('quoted-printable');
const striptags = require('striptags');
const {Imap} = require('isomorphic-core');
const SendingUtils = require('../local-api/sending-utils');


const SNIPPET_SIZE = 100

function extractContacts(values = []) {
  return values.map(v => {
    const {name, address: email} = mimelib.parseAddresses(v).pop()
    return {name, email}
  })
}

function getHeadersForId(data) {
  let participants = "";
  const emails = _.pluck(data.from.concat(data.to, data.cc, data.bcc), 'email');
  emails.sort().forEach((email) => {
    participants += email
  });
  return `${data.date}-${data.subject}-${participants}`;
}

function hashForHeaders(headers) {
  return cryptography.createHash('sha256').update(headers, 'utf8').digest('hex');
}

async function parseFromImap(imapMessage, desiredParts, {db, accountId, folder}) {
  const {Label} = db
  const body = {}
  const {headers, attributes} = imapMessage
  const xGmLabels = attributes['x-gm-labels']
  for (const {id, mimetype, encoding} of desiredParts) {
    if (!encoding) {
      body[mimetype] = imapMessage.parts[id];
    } else if (encoding.toLowerCase() === 'quoted-printable') {
      body[mimetype] = QuotedPrintable.decode(imapMessage.parts[id]);
    } else if (encoding.toLowerCase() === '7bit') {
      body[mimetype] = utf7.decode(imapMessage.parts[id]);
    } else if (encoding.toLowerCase() === '8bit') {
      body[mimetype] = Buffer.from(imapMessage.parts[id], 'utf8').toString();
    } else if (encoding && ['ascii', 'utf8', 'utf16le', 'ucs2', 'base64', 'latin1', 'binary', 'hex'].includes(encoding.toLowerCase())) {
      body[mimetype] = Buffer.from(imapMessage.parts[id], encoding.toLowerCase()).toString();
    } else {
      return Promise.reject(new Error(`Unknown encoding ${encoding}, mimetype ${mimetype}`))
    }
  }
  const parsedHeaders = Imap.parseHeader(headers);
  for (const key of ['x-gm-thrid', 'x-gm-msgid', 'x-gm-labels']) {
    parsedHeaders[key] = attributes[key];
  }

  const values = {
    id: hashForHeaders(getHeadersForId(parsedHeaders)),
    to: extractContacts(parsedHeaders.to),
    cc: extractContacts(parsedHeaders.cc),
    bcc: extractContacts(parsedHeaders.bcc),
    from: extractContacts(parsedHeaders.from),
    replyTo: extractContacts(parsedHeaders['reply-to']),
    accountId: accountId,
    body: body['text/html'] || body['text/plain'] || body['application/pgp-encrypted'] || '',
    snippet: body['text/plain'] ? body['text/plain'].substr(0, 255) : null,
    unread: !attributes.flags.includes('\\Seen'),
    starred: attributes.flags.includes('\\Flagged'),
    date: attributes.date,
    folderImapUID: attributes.uid,
    folderId: folder.id,
    folder: null,
    labels: [],
    headers: parsedHeaders,
    headerMessageId: parsedHeaders['message-id'] ? parsedHeaders['message-id'][0] : '',
    subject: parsedHeaders.subject[0],
  }

  // preserve whitespacing on plaintext emails -- has the side effect of monospacing, but
  // that seems OK and perhaps sometimes even desired (for e.g. ascii art, alignment)
  if (!body['text/html'] && body['text/plain']) {
    values.body = `<pre class="nylas-plaintext">${values.body}</pre>`;
  }

  // TODO: strip quoted text from snippets also
  if (values.snippet) {
    // trim and clean snippet which is alreay present (from values plaintext)
    values.snippet = values.snippet.replace(/[\n\r]/g, ' ').replace(/\s\s+/g, ' ')
    const loc = values.snippet.indexOf(' ', SNIPPET_SIZE);
    if (loc !== -1) {
      values.snippet = values.snippet.substr(0, loc);
    }
  } else if (values.body) {
    // create snippet from body, which is most likely html
    values.snippet = striptags(values.body).trim().substr(0, Math.min(values.body.length, SNIPPET_SIZE));
  }

  values.folder = folder
  if (xGmLabels) {
    values.folderImapXGMLabels = JSON.stringify(xGmLabels)
    values.labels = await Label.findXGMLabels(xGmLabels)
  }

  return values;
}

function fromJSON(db, data) {
  // TODO: events, metadata?
  const {Message} = db;
  const id = hashForHeaders(getHeadersForId(data))
  return Message.build({
    accountId: data.account_id,
    from: data.from,
    to: data.to,
    cc: data.cc,
    bcc: data.bcc,
    replyTo: data.reply_to,
    subject: data.subject,
    body: data.body,
    unread: true,
    isDraft: data.is_draft,
    isSent: false,
    version: 0,
    date: data.date,
    id: id,
    uploads: data.uploads,
  });
}

async function associateFromJSON(data, db) {
  const {Thread, Message} = db;

  const message = fromJSON(db, data);

  let replyToThread;
  let replyToMessage;
  if (data.thread_id != null) {
    replyToThread = await Thread.find({
      where: {id: data.thread_id},
      include: [{
        model: Message,
        as: 'messages',
        attributes: _.without(Object.keys(Message.attributes), 'body'),
      }],
    });
  }
  if (data.reply_to_message_id != null) {
    replyToMessage = await Message.findById(data.reply_to_message_id);
  }

  if (replyToThread && replyToMessage) {
    if (!replyToThread.messages.find((msg) => msg.id === replyToMessage.id)) {
      throw new SendingUtils.HTTPError(
        `Message ${replyToMessage.id} is not in thread ${replyToThread.id}`,
        400
      )
    }
  }

  let thread;
  if (replyToMessage) {
    SendingUtils.setReplyHeaders(message, replyToMessage);
    thread = await message.getThread();
  } else if (replyToThread) {
    thread = replyToThread;
    const previousMessages = thread.messages.filter(msg => !msg.isDraft);
    if (previousMessages.length > 0) {
      const lastMessage = previousMessages[previousMessages.length - 1]
      SendingUtils.setReplyHeaders(message, lastMessage);
    }
  } else {
    thread = Thread.build({
      accountId: message.accountId,
      subject: message.subject,
      firstMessageDate: message.date,
      lastMessageDate: message.date,
      lastMessageSentDate: message.date,
    })
  }

  const savedMessage = await message.save();
  const savedThread = await thread.save();
  await savedThread.addMessage(savedMessage);

  return savedMessage;
}

module.exports = {
  parseFromImap,
  fromJSON,
  associateFromJSON,
}
