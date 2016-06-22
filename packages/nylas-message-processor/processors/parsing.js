const {MailParser} = require('mailparser')
const SNIPPET_SIZE = 100

function Contact({name, address}) {
  return {
    name,
    email: address,
  }
}

const extractContacts = (field) => (field ? field.map(Contact) : [])

function processMessage({message}) {
  return new Promise((resolve, reject) => {
    const {rawHeaders, rawBody} = message
    const parser = new MailParser()
    parser.on('error', reject)
    parser.on('end', (mailObject) => {
      const {
        html,
        text,
        subject,
        from,
        to,
        cc,
        bcc,
        headers,
      } = mailObject

      // TODO pull attachments
      Object.assign(message, {
        subject,
        body: html,
        headers,
        from: extractContacts(from),
        to: extractContacts(to),
        cc: extractContacts(cc),
        bcc: extractContacts(bcc),
        messageId: headers['message-id'],
        snippet: text.slice(0, SNIPPET_SIZE),
      })
      resolve(message)
    });
    parser.write(rawHeaders)
    parser.write(rawBody);
    parser.end();
  })
}

module.exports = {
  order: 0,
  processMessage,
}
