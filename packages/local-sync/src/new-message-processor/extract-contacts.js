const cryptography = require('crypto');

function isContactVerified(contact) {
  // some suggestions: http://stackoverflow.com/questions/6317714/apache-camel-mail-to-identify-auto-generated-messages
  const regex = new RegExp(/^(noreply|no-reply|donotreply|mailer|support|webmaster|news(letter)?@)/ig)

  if (!contact.email) {
    return false;
  }
  if (regex.test(contact.email) || contact.email.length > 60) {
    return false
  }
  return true
}

function extractContacts({db, message}) {
  const {Contact} = db;

  let allContacts = [];
  ['to', 'from', 'bcc', 'cc'].forEach((field) => {
    allContacts = allContacts.concat(message[field])
  })

  const verifiedContacts = allContacts.filter(c => isContactVerified(c));
  return db.sequelize.transaction((transaction) => {
    return Promise.all(verifiedContacts.map((contact) =>
      Contact.upsert({
        name: contact.name,
        email: contact.email,
        accountId: message.accountId,
        id: cryptography.createHash('sha256').update(contact.email, 'utf8').digest('hex'),
      }, {
        transaction,
      })
    ))
  }).thenReturn(message)
}

module.exports = extractContacts
