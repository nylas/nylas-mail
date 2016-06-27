const mimelib = require('mimelib');
const SNIPPET_SIZE = 100

function Contact({name, address}) {
  return {
    name,
    email: address,
  }
}

const extractContacts = (values) =>
  (values || []).map(v => Contact(mimelib.parseAddresses(v).pop()))

function processMessage({message}) {
  if (message.snippet) {
    // trim and clean snippet which is alreay present (from message plaintext)
    message.snippet = message.snippet.replace(/[\n\r]/g, ' ')
    const loc = message.snippet.indexOf(' ', SNIPPET_SIZE);
    if (loc !== -1) {
      message.snippet = message.snippet.substr(0, loc);
    }
  } else if (message.body) {
    // create snippet from body, which is most likely html
    // TODO: Fanciness
    message.snippet = message.body.substr(0, Math.min(message.body.length, SNIPPET_SIZE));
  } else {
    console.log("Received message has no body or snippet.")
  }

  // extract data from the raw headers object
  message.messageId = message.headers['message-id'];
  for (const field of ['to', 'from', 'cc', 'bcc']) {
    message[field] = extractContacts(message.headers[field]);
  }

  return Promise.resolve(message);
}

module.exports = {
  order: 0,
  processMessage,
}
