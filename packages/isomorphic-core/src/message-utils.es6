/* eslint no-useless-escape: 0 */
import mailcomposer from 'mailcomposer'
const mimelib = require('mimelib');
const encoding = require('encoding');
const he = require('he');
const os = require('os');
const fs = require('fs');
const path = require('path');
const mkdirp = require('mkdirp');
const btoa = require('btoa')
const {APIError} = require('./errors');
const {deepClone} = require('./model-utils').default;

// Aiming for the former in length, but the latter is the hard db cutoff
const SNIPPET_SIZE = 100;
const SNIPPET_MAX_SIZE = 255;

// Copied from regexp-utils.coffee.
// FIXME @karim: share code, somehow.
// Test cases: https://regex101.com/r/cK0zD8/4
// Catches link tags containing which are:
// - Non empty
// - Not a mailto: link
// Returns the following capturing groups:
// 1. start of the opening a tag to href="
// 2. The contents of the href without quotes
// 3. the rest of the opening a tag
// 4. the contents of the a tag
// 5. the closing tag
function urlLinkTagRegex() {
  return new RegExp(/(<a.*?href\s*?=\s*?['"])((?!mailto).+?)(['"].*?>)([\s\S]*?)(<\/a>)/gim);
}

// Format of input: ['a@example.com, B <b@example.com>', 'c@example.com'],
// where each element of the array is the unparsed contents of a single
// element of the same header field. (It's totally valid to have multiple
// From/To/etc. headers on the same email.)
function parseContacts(input) {
  if (!input || input.length === 0 || !input[0]) {
    return [];
  }
  let contacts = [];
  for (const headerLine of input) {
    const values = mimelib.parseAddresses(headerLine);
    if (!values || values.length === 0) {
      continue;
    }
    contacts = contacts.concat(values.map(v => {
      if (!v || v.length === 0) {
        return null
      }
      const {name, address: email} = v;
      return {name, email};
    })
    .filter(c => c != null))
  }
  return contacts;
}

function parseSnippet(body) {
  const doc = new DOMParser().parseFromString(body, 'text/html')
  const skipTags = new Set(['TITLE', 'SCRIPT', 'STYLE', 'IMG']);
  const noSpaceTags = new Set(['B', 'I', 'STRONG', 'EM', 'SPAN']);

  const treeWalker = document.createTreeWalker(doc, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT, (node) => {
    if (skipTags.has(node.tagName)) {
      // skip this node and all its children
      return NodeFilter.FILTER_REJECT;
    }
    if (node.nodeType === Node.TEXT_NODE) {
      const nodeValue = node.nodeValue ? node.nodeValue.trim() : null;
      if (nodeValue) {
        return NodeFilter.FILTER_ACCEPT;
      }
      return NodeFilter.FILTER_SKIP;
    }
    return NodeFilter.FILTER_ACCEPT;
  });

  let extractedText = "";
  let lastNodeTag = "";
  while (treeWalker.nextNode()) {
    if (treeWalker.currentNode.nodeType === Node.ELEMENT_NODE) {
      lastNodeTag = treeWalker.currentNode.nodeName;
    } else {
      if (extractedText && !noSpaceTags.has(lastNodeTag)) {
        extractedText += " ";
      }
      extractedText += treeWalker.currentNode.nodeValue;
      if (extractedText.length > SNIPPET_MAX_SIZE) {
        break;
      }
    }
  }
  const snippetText = extractedText.trim();

  // clean up and trim snippet
  let trimmed = snippetText.replace(/[\n\r]/g, ' ').replace(/\s\s+/g, ' ').substr(0, SNIPPET_MAX_SIZE);
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

// In goes arrays of text, out comes arrays of RFC2822 Message-Ids. Luckily,
// these days most all text in In-Reply-To, Message-Id, and References headers
// actually conforms to the spec.
function parseReferences(input) {
  if (!input || !input.length || !input[0]) {
    return [];
  }
  const references = new Set();
  for (const headerLine of input) {
    for (const ref of headerLine.split(/[\s,]+/)) {
      if (/^<.*>$/.test(ref)) {
        references.add(ref);
      }
    }
  }
  return Array.from(references);
}

function htmlifyPlaintext(text) {
  const escapedText = he.escape(text);
  return `<pre class="nylas-plaintext">${escapedText}</pre>`;
}


function replaceMessageIdInBodyTrackingLinks(messageId, originalBody) {
  const regex = new RegExp(`(https://.+?)MESSAGE_ID`, 'g')
  return originalBody.replace(regex, `$1${messageId}`)
}


function stripTrackingLinksFromBody(originalBody) {
  let body = originalBody.replace(/<img class="n1-open"[^<]+src="([a-zA-Z0-9-_:/.]*)">/g, () => {
    return "";
  });
  body = body.replace(urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
    const param = url.split("?")[1];
    if (param) {
      const link = decodeURIComponent(param.split("=")[1]);
      return `${prefix}${link}${suffix}${content}${closingTag}`;
    }
    return match;
  });
  return body;
}


function buildTrackingBodyForRecipient({baseMessage, recipient, usesOpenTracking, usesLinkTracking} = {}) {
  const {id: messageId, body} = baseMessage
  const encodedEmail = btoa(recipient.email)
    .replace(/\+/g, '-')
    .replace(/\//g, '_');
  let customBody = body
  if (usesOpenTracking) {
    customBody = customBody.replace(/<img class="n1-open"[^<]+src="([a-zA-Z0-9-_:/.]*)">/g, (match, url) => {
      return `<img class="n1-open" width="0" height="0" style="border:0; width:0; height:0;" src="${url}?r=${encodedEmail}">`;
    });
  }
  if (usesLinkTracking) {
    customBody = customBody.replace(urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
      return `${prefix}${url}&r=${encodedEmail}${suffix}${content}${closingTag}`;
    });
  }
  return replaceMessageIdInBodyTrackingLinks(messageId, customBody);
}


function getReplyHeaders(messageReplyingTo) {
  let inReplyTo;
  let references;
  if (messageReplyingTo.headerMessageId) {
    inReplyTo = messageReplyingTo.headerMessageId;
    if (messageReplyingTo.references) {
      const refById = {};
      for (const ref of messageReplyingTo.references) {
        refById[ref.id] = ref;
      }
      references = [];
      for (const referenceId of messageReplyingTo.referencesOrder) {
        references.push(refById[referenceId].rfc2822MessageId);
      }
      if (!references.includes(messageReplyingTo.headerMessageId)) {
        references.push(messageReplyingTo.headerMessageId);
      }
    } else {
      references = [messageReplyingTo.headerMessageId];
    }
  }
  return {inReplyTo, references}
}

function bodyFromParts(imapMessage, desiredParts) {
  let body = '';
  for (const {id, mimeType, transferEncoding, charset} of desiredParts) {
    let decoded = '';
    // see https://www.w3.org/Protocols/rfc1341/5_Content-Transfer-Encoding.html
    if ((/quot(ed)?[-/]print(ed|able)?/gi).test(transferEncoding)) {
      decoded = mimelib.decodeQuotedPrintable(imapMessage.parts[id], charset);
    } else if ((/base64/gi).test(transferEncoding)) {
      decoded = mimelib.decodeBase64(imapMessage.parts[id], charset);
    } else {
      // Treat this as having no encoding and decode based only on the charset
      //
      // According to https://tools.ietf.org/html/rfc2045#section-5.2,
      // this should default to ascii; however, if we don't get a charset,
      // it's possible clients (like nodemailer) encoded the data as utf-8
      // anyway. Since ascii is a strict subset of utf-8, it's safer to
      // try and decode as utf-8 if we don't have the charset.
      //
      // (This applies to decoding quoted-printable and base64 as well. The
      // mimelib library, if charset is null, will default to utf-8)
      //
      decoded = encoding.convert(imapMessage.parts[id], 'utf-8', charset).toString('utf-8');
    }
    // desiredParts are in order of the MIME tree walk, e.g. 1.1, 1.2, 2...,
    // and for multipart/alternative arrays, we have already pulled out the
    // highest fidelity part (generally HTML).
    //
    // Therefore, the correct way to display multiple parts is to simply
    // concatenate later ones with the body of the previous MIME parts.
    //
    // This may seem kind of weird, but some MUAs _do_ send out whack stuff
    // like an HTML body followed by a plaintext footer.
    if (mimeType === 'text/plain') {
      body += htmlifyPlaintext(decoded);
    } else {
      body += decoded;
    }
  }
  // sometimes decoding results in a NUL-terminated body string, which makes
  // SQLite blow up with an 'unrecognized token' error
  body = body.replace(/\0/g, '');

  return body;
}

// Since we only fetch the MIME structure and specific desired MIME parts from
// IMAP, we unfortunately can't use an existing library like mailparser to parse
// the message, and have to do fun stuff like deal with character sets and
// content-transfer-encodings ourselves.
async function parseFromImap(imapMessage, desiredParts, {db, accountId, folder}) {
  const {Message, Label} = db;
  const {attributes} = imapMessage;

  // this key name can change depending on which subset of headers we're downloading,
  // so to prevent having to update this code every time we change the set,
  // dynamically look up the key instead
  const headerKey = Object.keys(imapMessage.parts).filter(k => k.startsWith('HEADER'))[0]
  const headers = imapMessage.parts[headerKey].toString('ascii')
  const parsedHeaders = mimelib.parseHeaders(headers);
  for (const key of ['x-gm-thrid', 'x-gm-msgid', 'x-gm-labels']) {
    parsedHeaders[key] = attributes[key];
  }

  const parsedMessage = {
    to: parseContacts(parsedHeaders.to),
    cc: parseContacts(parsedHeaders.cc),
    bcc: parseContacts(parsedHeaders.bcc),
    from: parseContacts(parsedHeaders.from),
    replyTo: parseContacts(parsedHeaders['reply-to']),
    accountId: accountId,
    body: bodyFromParts(imapMessage, desiredParts),
    snippet: null,
    unread: !attributes.flags.includes('\\Seen'),
    starred: attributes.flags.includes('\\Flagged'),
    // We limit drafts to the drafts and all mail folders because some clients
    // may send messages and improperly leave the draft flag set, and also
    // because we want to exclude drafts moved to the trash from the drafts view
    // see https://github.com/nylas/cloud-core/commit/1433921a166ddcba7c269158d65febb7928767d8
    // & associated phabricator bug https://phab.nylas.com/T5696
    isDraft: (
      ['drafts', 'all'].includes(folder.role) &&
      (
        attributes.flags.includes('\\Draft') ||
        (parsedHeaders['x-gm-labels'] || []).includes('\\Draft')
      )
    ),
    // We prefer the date from the message headers because the date is one of
    // the fields we use for generating unique message IDs, and the server
    // INTERNALDATE, `attributes.date`, may differ across accounts for the same
    // message. If the Date header is not included in the message, we fall
    // back to the INTERNALDATE and it's possible we'll generate different IDs
    // for the same message delivered to different accounts (which is better
    // than having message ID collisions for different messages, which could
    // happen if we did not include the date).
    date: parsedHeaders.date ? parsedHeaders.date[0] : imapMessage.attributes.date,
    folderImapUID: attributes.uid,
    folderId: folder.id,
    folder: null,
    labels: [],
    headerMessageId: parseReferences(parsedHeaders['message-id'])[0],
    // References are not saved on the message model itself, but are later
    // converted to associated Reference objects so we can index them. Since we
    // don't do tree threading, we don't need to care about In-Reply-To
    // separately, and can simply associate them all in the same way.
    // Generally, References already contains the Message-IDs in In-Reply-To,
    // but we concat and dedupe just in case.
    references: parseReferences(
      (parsedHeaders.references || []).concat(
        (parsedHeaders['in-reply-to'] || []), (parsedHeaders['message-id'] || [])
      )
    ),
    gMsgId: parsedHeaders['x-gm-msgid'],
    gThrId: parsedHeaders['x-gm-thrid'],
    subject: parsedHeaders.subject ? parsedHeaders.subject[0] : '(no subject)',
  }


  /**
   * mimelib will return a string date with the leading zero of single
   * digit dates truncated. e.g. February 1 instead of February 01. When
   * we set Message Date headers, we use javascript's `toUTCString` which
   * zero pads digit dates. To make the hashes line up, we need to ensure
   * that the date string used in the ID generation is also zero-padded.
   */
  const messageForHashing = deepClone(parsedMessage)
  messageForHashing.date = Message.dateString(parsedMessage.date);
  // Inversely to `buildForSend`, we leave the date header as it is so that the
  // format is consistent for the generative IDs, then convert it to a Date object
  parsedMessage.id = Message.hash(messageForHashing)
  parsedMessage.date = new Date(Date.parse(parsedMessage.date));

  parsedMessage.snippet = parseSnippet(parsedMessage.body);

  parsedMessage.folder = folder;

  const xGmLabels = parsedHeaders['x-gm-labels']
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


async function buildForSend(db, json) {
  const {Thread, Message, Reference} = db
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
    replyToMessage = await Message.findById(
      json.reply_to_message_id,
      { include: [{model: Reference, as: 'references', attributes: ['id', 'rfc2822MessageId']}] }
    )
  }

  if (replyToThread && replyToMessage) {
    if (!replyToThread.messages.find((msg) => msg.id === replyToMessage.id)) {
      throw new APIError(`Message ${replyToMessage.id} is not in thread ${replyToThread.id}`, 400)
    }
  }

  let thread;
  let replyHeaders = {};
  let inReplyToLocalMessageId;
  if (replyToMessage) {
    inReplyToLocalMessageId = replyToMessage.id;
    replyHeaders = getReplyHeaders(replyToMessage);
    thread = await replyToMessage.getThread();
  } else if (replyToThread) {
    thread = replyToThread;
    const previousMessages = thread.messages.filter(msg => !msg.isDraft);
    if (previousMessages.length > 0) {
      const lastMessage = previousMessages[previousMessages.length - 1]
      inReplyToLocalMessageId = lastMessage.id;
      replyHeaders = getReplyHeaders(lastMessage);
    }
  }

  const {inReplyTo, references} = replyHeaders
  const date = new Date()
  const message = {
    accountId: json.account_id,
    threadId: thread ? thread.id : null,
    headerMessageId: Message.buildHeaderMessageId(json.client_id),
    from: json.from,
    to: json.to,
    cc: json.cc,
    bcc: json.bcc,
    replyTo: json.reply_to,
    subject: json.subject,
    body: json.body,
    unread: false,
    isDraft: json.draft,
    isSent: false,
    version: 0,
    date: date,
    inReplyToLocalMessageId: inReplyToLocalMessageId,
    uploads: json.uploads,
  }
  // We have to clone the message and change the date for hashing because the
  // date we get later when we parse from IMAP is a different format, per the
  // nodemailer buildmail function that gives us the raw message and replaces
  // the date header with this modified UTC string
  // https://github.com/nodemailer/buildmail/blob/master/lib/buildmail.js#L470
  const messageForHashing = deepClone(message)
  messageForHashing.date = Message.dateString(date)
  message.id = Message.hash(messageForHashing)
  message.body = replaceMessageIdInBodyTrackingLinks(message.id, message.body)
  const instance = Message.build(message)

  // TODO we set these temporary properties which aren't stored in the database
  // model because SendmailClient requires them to send the message with the
  // correct headers.
  // This should be cleaned up
  instance.inReplyTo = inReplyTo;
  instance.references = references;
  return instance;
}

const formatParticipants = (participants) => {
  // Something weird happens with the mime building when the participant name
  // has an @ symbol in it (e.g. a name and email of hello@gmail.com turns into
  // 'hello@ <gmail.com hello@gmail.com>'), so replace it with whitespace.
  return participants.map(p => `${p.name.replace('@', ' ')} <${p.email}>`).join(',');
}

// Transforms the message into a json object with the properties formatted in
// the way mailer libraries (e.g. nodemailer, mailcomposer) expect.
function getMailerPayload(message) {
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

async function buildMime(message, {includeBcc = false} = {}) {
  const payload = getMailerPayload(message)
  const builder = mailcomposer(payload)
  const mimeNode = await (new Promise((resolve, reject) => {
    builder.build((error, result) => (
      error ? reject(error) : resolve(result)
    ))
  }));
  if (!includeBcc || !message.bcc || message.bcc.length === 0) {
    return mimeNode.toString('ascii')
  }
  return `Bcc: ${formatParticipants(message.bcc)}\n${mimeNode.toString('ascii')}`
}

module.exports = {
  buildForSend,
  getReplyHeaders,
  parseFromImap,
  parseSnippet,
  parseContacts,
  stripTrackingLinksFromBody,
  buildTrackingBodyForRecipient,
  replaceMessageIdInBodyTrackingLinks,
  getMailerPayload,
  buildMime,
}
