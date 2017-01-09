/* eslint no-useless-escape: 0 */
const mimelib = require('mimelib');
const encoding = require('encoding');
const he = require('he');
const os = require('os');
const fs = require('fs');
const path = require('path');
const mkdirp = require('mkdirp');
const {Errors: {APIError}} = require('isomorphic-core');
const {N1CloudAPI, RegExpUtils, Utils} = require('nylas-exports');

// Aiming for the former in length, but the latter is the hard db cutoff
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
  const values = mimelib.parseAddresses(input[0]);
  if (!values || values.length === 0 || !input[0]) {
    return [];
  }
  return values.map(v => {
    if (!v || v.length === 0) {
      return null
    }
    const {name, address: email} = v;
    return {name, email};
  })
  .filter(c => c != null)
}


function extractSnippet(body) {
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


// Preserve whitespacing on plaintext emails -- has the side effect of
// monospacing, but that seems OK and perhaps sometimes even desired (for e.g.
// ascii art, alignment)
function htmlifyPlaintext(text) {
  const escapedText = he.escape(text);
  return `<pre class="nylas-plaintext">${escapedText}</pre>`;
}


function replaceMessageIdInBodyTrackingLinks(messageId, originalBody) {
  const regex = new RegExp(`(${N1CloudAPI.APIRoot}.+?)MESSAGE_ID`, 'g')
  return originalBody.replace(regex, `$1${messageId}`)
}


function stripTrackingLinksFromBody(originalBody) {
  let body = originalBody.replace(/<img class="n1-open"[^<]+src="([a-zA-Z0-9-_:/.]*)">/g, () => {
    return "";
  });
  body = body.replace(RegExpUtils.urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
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
    customBody = customBody.replace(RegExpUtils.urlLinkTagRegex(), (match, prefix, url, suffix, content, closingTag) => {
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
      references = messageReplyingTo.references.concat(messageReplyingTo.headerMessageId);
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
    if (!transferEncoding || new Set(['7bit', '8bit', 'binary']).has(transferEncoding.toLowerCase())) {
      // NO transfer encoding has been performed --- how to decode to a string
      // depends ONLY on the charset, which defaults to 'ascii' according to
      // https://tools.ietf.org/html/rfc2045#section-5.2
      decoded = encoding.convert(imapMessage.parts[id], 'utf-8', charset || 'ascii').toString('utf-8');
    } else if (transferEncoding.toLowerCase() === 'quoted-printable') {
      decoded = mimelib.decodeQuotedPrintable(imapMessage.parts[id], charset || 'ascii');
    } else if (transferEncoding.toLowerCase() === 'base64') {
      decoded = mimelib.decodeBase64(imapMessage.parts[id], charset || 'ascii');
    } else {
      // custom x-token content-transfer-encodings
      return Promise.reject(new Error(`Unsupported Content-Transfer-Encoding ${transferEncoding}, mimetype ${mimeType}`))
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
    to: extractContacts(parsedHeaders.to),
    cc: extractContacts(parsedHeaders.cc),
    bcc: extractContacts(parsedHeaders.bcc),
    from: extractContacts(parsedHeaders.from),
    replyTo: extractContacts(parsedHeaders['reply-to']),
    accountId: accountId,
    body: bodyFromParts(imapMessage, desiredParts),
    snippet: null,
    unread: !attributes.flags.includes('\\Seen'),
    starred: attributes.flags.includes('\\Flagged'),
    // Make sure we use the date from the headers because we use the header date
    // for generating message ids.
    // `attributes.date` is the server generated date and might differ from the
    // header across accounts
    // TODO: how to exclude the date header from the hash if there is no
    // Date: header and we have to use the IMAP server date for message sort
    // & display? seems like it should be OK within an account, but might
    // generate different message IDs across different accounts (which I
    // don't think is a problem we're intending to solve...)
    date: parsedHeaders.date ? parsedHeaders.date[0] : imapMessage.attributes.date,
    folderImapUID: attributes.uid,
    folderId: folder.id,
    folder: null,
    labels: [],
    headerMessageId: parsedHeaders['message-id'] ? parsedHeaders['message-id'][0] : '',
    gMsgId: parsedHeaders['x-gm-msgid'],
    gThrId: parsedHeaders['x-gm-thrid'],
    subject: parsedHeaders.subject ? parsedHeaders.subject[0] : '(no subject)',
  }
  // Inversely to `buildForSend`, we leave the date header as it is so that the
  // format is consistent for the generative IDs, then convert it to a Date object
  parsedMessage.id = Message.hash(parsedMessage)
  parsedMessage.date = new Date(Date.parse(parsedMessage.date))

  parsedMessage.snippet = extractSnippet(parsedMessage.body);
  parsedMessage.folder = folder;

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
  const date = new Date()
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
    date: date,
    uploads: json.uploads,
  }
  // We have to clone the message and change the date for hashing because the
  // date we get later when we parse from IMAP is a different format, per the
  // nodemailer buildmail function that gives us the raw message and replaces
  // the date header with this modified UTC string
  // https://github.com/nodemailer/buildmail/blob/master/lib/buildmail.js#L470
  const messageForHashing = Utils.deepClone(message)
  messageForHashing.date = date.toUTCString().replace(/GMT/, '+0000')
  message.id = Message.hash(messageForHashing)
  message.body = replaceMessageIdInBodyTrackingLinks(message.id, message.body)
  return Message.build(message)
}

module.exports = {
  buildForSend,
  parseFromImap,
  extractSnippet,
  extractContacts,
  stripTrackingLinksFromBody,
  buildTrackingBodyForRecipient,
  replaceMessageIdInBodyTrackingLinks,
}
