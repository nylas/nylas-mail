const cryptography = require('crypto');

function isContactMeaningful(contact) {
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

  const meaningfulContacts = allContacts.filter(c => isContactMeaningful(c));

  await db.sequelize.transaction(async (transaction) => {
    const promises = [];

    for (const c of meaningfulContacts) {
      const id = cryptography.createHash('sha256').update(c.email, 'utf8').digest('hex');
      const existing = await db.Contact.findById(id);
      const cdata = {
        id,
        name: c.name,
        email: c.email,
        accountId: message.accountId,
      };

      if (!existing) {
        promises.push(db.Contact.create(cdata, {transaction}));
      } else {
        const updateRequired = (cdata.name !== existing.name);
        if (updateRequired) {
          promises.push(existing.update(cdata, {transaction}));
        }
      }
    }
    await Promise.all(promises);
  })

  return message;
}

module.exports = extractContacts
