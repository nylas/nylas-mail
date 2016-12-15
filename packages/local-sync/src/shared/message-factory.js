/* eslint no-useless-escape: 0 */
const mimelib = require('mimelib');
const encoding = require('encoding');
const he = require('he');
const os = require('os');
const fs = require('fs');
const path = require('path')
const mkdirp = require('mkdirp');
const {Imap} = require('isomorphic-core');
const {APIError} = require('./errors')

// aiming for the former in length, but the latter is the hard db cutoff
const SNIPPET_SIZE = 100;
const SNIPPET_MAX_SIZE = 255;

// The input is the value of a to/cc/bcc/from header as parsed by the imap
// library we're using, but it currently parses them in a weird format. If an
// email is sent to a@example.com and b@example.com, the parsed output of the
// 'to' header is ['a@example.com, b@example.com']. (Note both emails are in
// the same string.) When fixed, this function will need to update accordingly.
function extractContacts(input) {
  if (!input || input.length === 0 || !input[0]) {
    return [];
  }
  const s = `["${input[0].replace(/"/g, '\\"').replace(/, /g, '", "')}"]`;
  const values = JSON.parse(s);
  return values.map(v => {
    const {name, address: email} = mimelib.parseAddresses(v).pop()
    return {name, email}
  })
}

/*
Iteratively walk the DOM of this document's <body>, calling the callback on
each node. Skip any nodes and the skipTags set, including their children.
*/
function _walkBodyDOM(doc, callback, skipTags) {
  let nodes = Array.from(doc.body.childNodes);

  while (nodes.length) {
    const node = nodes.shift();

    callback(node);

    if (!skipTags.has(node.tagName)) {
      if (node.childNodes && node.childNodes.length) {
        nodes = Array.from(node.childNodes).concat(nodes);
      }
    }
  }
}

function extractSnippet(plainBody, htmlBody) {
  let snippetText = plainBody || '';
  if (htmlBody) {
    const doc = new DOMParser().parseFromString(htmlBody, 'text/html')
    const extractedTextElements = [];

    _walkBodyDOM(doc, (node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        const nodeValue = node.nodeValue ? node.nodeValue.trim() : null;
        if (nodeValue) {
          extractedTextElements.push(nodeValue);
        }
      }
    }, new Set(['TITLE', 'SCRIPT', 'STYLE', 'IMG']));

    const extractedText = extractedTextElements.join(' ').trim();
    if (extractedText) {
      snippetText = extractedText;
    }
  }

  // clean up and trim snippet
  let trimmed = snippetText.trim().replace(/[\n\r]/g, ' ').replace(/\s\s+/g, ' ').substr(0, SNIPPET_MAX_SIZE);
  if (trimmed) {
  // TODO: strip quoted text from snippets also
    // trim down to approx. SNIPPET_SIZE w/out cutting off words right in the
    // middle (if possible)
    const wordBreak = trimmed.indexOf(' ', SNIPPET_SIZE);
    if (wordBreak !== -1) {
      trimmed = trimmed.substr(0, wordBreak);
    }
  }
  return trimmed;
}

/*
Preserve whitespacing on plaintext emails -- has the side effect of
monospacing, but that seems OK and perhaps sometimes even desired (for e.g.
ascii art, alignment)
*/
function HTMLifyPlaintext(text) {
  const escapedText = he.escape(text);
  return `<pre class="nylas-plaintext">${escapedText}</pre>`;
}

/*
Since we only fetch the MIME structure and specific desired MIME parts from
IMAP, we unfortunately can't use an existing library like mailparser to parse
the message, and have to do fun stuff like deal with character sets and
content-transfer-encodings ourselves.
*/
async function parseFromImap(imapMessage, desiredParts, {db, accountId, folder}) {
  const {Message, Label} = db
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
    gMsgId: parsedHeaders['x-gm-msgid'],
    subject: parsedHeaders.subject[0],
  }
  parsedMessage.id = Message.hash(parsedMessage)

  if (!body['text/html'] && body['text/plain']) {
    parsedMessage.body = HTMLifyPlaintext(body['text/plain']);
  }

  parsedMessage.snippet = extractSnippet(body['text/plain'], body['text/html']);
  parsedMessage.folder = folder

  // TODO: unclear if this is necessary given we already have parsed labels
  const xGmLabels = attributes['x-gm-labels']
  if (xGmLabels) {
    parsedMessage.folderImapXGMLabels = JSON.stringify(xGmLabels)
    parsedMessage.labels = await Label.findXGMLabels(xGmLabels)
  }

  if (process.env.NYLAS_DEBUG) {
    const outJSON = JSON.stringify({imapMessage, desiredParts, result: parsedMessage});
    const outDir = path.join(os.tmpdir(), "k2-parse-output", folder.name)
    const outFile = path.join(outDir, imapMessage.attributes.uid.toString());
    mkdirp.sync(outDir);
    fs.writeFileSync(outFile, outJSON);
  }

  return parsedMessage;
}

function getReplyHeaders(messageReplyingTo) {
  let inReplyTo;
  let references;
  if (messageReplyingTo.headerMessageId) {
    inReplyTo = messageReplyingTo.headerMessageId;
    if (messageReplyingTo.references) {
      references = messageReplyingTo.references.concat(messageReplyingTo.headerMessageId);
    } else {
      references = [messageReplyingTo.headerMessageId];
    }
  }
  return {inReplyTo, references}
}

function replaceBodyMessageIds(messageId, originalBody) {
  const env = NylasEnv.config.get('env')
  const serverUrl = {
    local: 'http:\/\/lvh\.me:5100',
    development: 'http:\/\/lvh\.me:5100',
    staging: 'https:\/\/n1-staging\.nylas\.com',
    production: 'https:\/\/n1\.nylas\.com',
  }[env];
  const regex = new RegExp(`(${serverUrl}.+?)MESSAGE_ID`, 'g')
  return originalBody.replace(regex, `$1${messageId}`)
}

async function buildForSend(db, json) {
  const {Thread, Message} = db
  let replyToThread;
  let replyToMessage;

  if (json.thread_id != null) {
    replyToThread = await Thread.find({
      where: {id: json.thread_id},
      include: [{
        model: Message,
        as: 'messages',
        attributes: ['id'],
      }],
    });
  }

  if (json.reply_to_message_id != null) {
    replyToMessage = await Message.findById(json.reply_to_message_id);
  }

  if (replyToThread && replyToMessage) {
    if (!replyToThread.messages.find((msg) => msg.id === replyToMessage.id)) {
      throw new APIError(`Message ${replyToMessage.id} is not in thread ${replyToThread.id}`, 400)
    }
  }

  let thread;
  let replyHeaders = {};
  if (replyToMessage) {
    replyHeaders = getReplyHeaders(replyToMessage);
    thread = await replyToMessage.getThread();
  } else if (replyToThread) {
    thread = replyToThread;
    const previousMessages = thread.messages.filter(msg => !msg.isDraft);
    if (previousMessages.length > 0) {
      const lastMessage = previousMessages[previousMessages.length - 1]
      replyHeaders = getReplyHeaders(lastMessage);
    }
  }

  const {inReplyTo, references} = replyHeaders
  const message = {
    accountId: json.account_id,
    threadId: thread ? thread.id : null,
    headerMessageId: Message.buildHeaderMessageId(json.client_id),
    from: json.from,
    to: json.to,
    cc: json.cc,
    bcc: json.bcc,
    references,
    inReplyTo,
    replyTo: json.reply_to,
    subject: json.subject,
    body: json.body,
    unread: true,
    isDraft: json.draft,
    isSent: false,
    version: 0,
    date: new Date(),
    uploads: json.uploads,
  }
  message.id = Message.hash(message)
  message.body = replaceBodyMessageIds(message.id, message.body)
  return Message.build(message)
}

module.exports = {
  buildForSend,
  parseFromImap,
  extractSnippet,
  replaceBodyMessageIds,
}
