const _ = require('underscore');
const cryptography = require('crypto');
const mimelib = require('mimelib');
const striptags = require('striptags');
const encoding = require('encoding');

const {Imap} = require('isomorphic-core');
const Errors = require('./errors');

// aiming for the former in length, but the latter is the hard db cutoff
const SNIPPET_SIZE = 100;
const SNIPPET_MAX_SIZE = 255;

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

function setReplyHeaders(newMessage, prevMessage) {
  if (prevMessage.messageIdHeader) {
    newMessage.inReplyTo = prevMessage.headerMessageId;
    if (prevMessage.references) {
      newMessage.references = prevMessage.references.concat(prevMessage.headerMessageId);
    } else {
      newMessage.references = [prevMessage.messageIdHeader];
    }
  }
}

/*
Since we only fetch the MIME structure and specific desired MIME parts from
IMAP, we unfortunately can't use an existing library like mailparser to parse
the message, and have to do fun stuff like deal with character sets and
content-transfer-encodings ourselves.
*/
async function parseFromImap(imapMessage, desiredParts, {db, accountId, folder}) {
  const {Label} = db
  const {attributes} = imapMessage

  const body = {}
  for (const {id, mimetype, transferEncoding, charset} of desiredParts) {
    // see https://www.w3.org/Protocols/rfc1341/5_Content-Transfer-Encoding.html
    if (!transferEncoding || new Set(['7bit', '8bit']).has(transferEncoding.toLowerCase())) {
      // NO transfer encoding has been performed --- how to decode to a string
      // depends ONLY on the charset, which defaults to 'ascii' according to
      // https://tools.ietf.org/html/rfc2045#section-5.2
      const convertedBuffer = encoding.convert(imapMessage.parts[id], 'utf-8', charset || 'ascii')
      body[mimetype] = convertedBuffer.toString('utf-8');
    } else if (transferEncoding.toLowerCase() === 'quoted-printable') {
      body[mimetype] = mimelib.decodeQuotedPrintable(imapMessage.parts[id], charset || 'ascii');
    } else if (transferEncoding.toLowerCase() === 'base64') {
      body[mimetype] = mimelib.decodeBase64(imapMessage.parts[id], charset || 'ascii');
    } else {
      // 'binary' and custom x-token content-transfer-encodings
      return Promise.reject(new Error(`Unsupported Content-Transfer-Encoding ${transferEncoding}, mimetype ${mimetype}`))
    }
  }
  const headers = imapMessage.headers.toString('ascii');
  const parsedHeaders = Imap.parseHeader(headers);
  for (const key of ['x-gm-thrid', 'x-gm-msgid', 'x-gm-labels']) {
    parsedHeaders[key] = attributes[key];
  }

  const parsedMessage = {
    id: hashForHeaders(getHeadersForId(parsedHeaders)),
    to: extractContacts(parsedHeaders.to),
    cc: extractContacts(parsedHeaders.cc),
    bcc: extractContacts(parsedHeaders.bcc),
    from: extractContacts(parsedHeaders.from),
    replyTo: extractContacts(parsedHeaders['reply-to']),
    accountId: accountId,
    body: body['text/html'] || body['text/plain'] || body['application/pgp-encrypted'] || '',
    snippet: null,
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
    parsedMessage.body = `<pre class="nylas-plaintext">${parsedMessage.body}</pre>`;
  }

  // populate initial snippet
  if (body['text/plain']) {
    parsedMessage.snippet = body['text/plain'].trim().substr(0, SNIPPET_MAX_SIZE);
  } else if (parsedMessage.body) {
    // create snippet from body, which is most likely html. we strip tags but
    // don't currently support stripping embedded CSS
    parsedMessage.snippet = striptags(parsedMessage.body).trim().substr(0,
      Math.min(parsedMessage.body.length, SNIPPET_MAX_SIZE));
  }

  // clean up and trim snippet
  if (parsedMessage.snippet) {
  // TODO: strip quoted text from snippets also
    parsedMessage.snippet = parsedMessage.snippet.replace(/[\n\r]/g, ' ').replace(/\s\s+/g, ' ')
    // trim down to approx. SNIPPET_SIZE w/out cutting off words right in the
    // middle (if possible)
    const wordBreak = parsedMessage.snippet.indexOf(' ', SNIPPET_SIZE);
    if (wordBreak !== -1) {
      parsedMessage.snippet = parsedMessage.snippet.substr(0, wordBreak);
    }
  }

  parsedMessage.folder = folder

  // TODO: unclear if this is necessary given we already have parsed labels
  const xGmLabels = attributes['x-gm-labels']
  if (xGmLabels) {
    parsedMessage.folderImapXGMLabels = JSON.stringify(xGmLabels)
    parsedMessage.labels = await Label.findXGMLabels(xGmLabels)
  }

  return parsedMessage;
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
      throw new Errors.HTTPError(
        `Message ${replyToMessage.id} is not in thread ${replyToThread.id}`,
        400
      )
    }
  }

  let thread;
  if (replyToMessage) {
    setReplyHeaders(message, replyToMessage);
    thread = await message.getThread();
  } else if (replyToThread) {
    thread = replyToThread;
    const previousMessages = thread.messages.filter(msg => !msg.isDraft);
    if (previousMessages.length > 0) {
      const lastMessage = previousMessages[previousMessages.length - 1]
      setReplyHeaders(message, lastMessage);
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
