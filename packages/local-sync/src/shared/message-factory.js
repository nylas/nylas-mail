const utf7 = require('utf7').imap;
const mimelib = require('mimelib');
const QuotedPrintable = require('quoted-printable');
const {Imap} = require('isomorphic-core')

const SNIPPET_SIZE = 100

function extractContacts(values = []) {
  return values.map(v => {
    const {name, address: email} = mimelib.parseAddresses(v).pop()
    return {name, email}
  })
}

async function parseFromImap(imapMessage, desiredParts, {db, accountId, folder}) {
  const {Message, Label} = db
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
    id: Message.hashForHeaders(headers),
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

  if (values.snippet) {
    // trim and clean snippet which is alreay present (from values plaintext)
    values.snippet = values.snippet.replace(/[\n\r]/g, ' ').replace(/\s\s+/g, ' ')
    const loc = values.snippet.indexOf(' ', SNIPPET_SIZE);
    if (loc !== -1) {
      values.snippet = values.snippet.substr(0, loc);
    }
  } else if (values.body) {
    // create snippet from body, which is most likely html
    // TODO: Fanciness
    values.snippet = values.body.substr(0, Math.min(values.body.length, SNIPPET_SIZE));
  }

  values.folder = folder
  if (xGmLabels) {
    values.folderImapXGMLabels = JSON.stringify(xGmLabels)
    values.labels = await Label.findXGMLabels(xGmLabels)
  }

  return values;
}

module.exports = {
  parseFromImap,
}
