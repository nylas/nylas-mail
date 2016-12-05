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

async function extractContacts({db, message}) {
  let allContacts = [];
  ['to', 'from', 'bcc', 'cc'].forEach((field) => {
    allContacts = allContacts.concat(message[field])
  })

  const verifiedContacts = allContacts.filter(c => isContactVerified(c));
  return db.sequelize.transaction(async (transaction) => {
    for (const c of verifiedContacts) {
      const id = cryptography.createHash('sha256').update(c.email, 'utf8').digest('hex');
      let contact = await db.Contact.findById(id);
      const cdata = {
        name: c.name,
        email: c.email,
        accountId: message.accountId,
        id: id,
      };
      
      if (!contact) {
        contact = await db.Contact.create(cdata)
      } else {
        await contact.update(cdata);
      }
    }
  }).thenReturn(message)
}

module.exports = extractContacts
