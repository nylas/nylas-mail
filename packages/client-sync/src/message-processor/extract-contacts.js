const Sequelize = require('sequelize');

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

async function extractContacts({db, messageValues, logger = console} = {}) {
  const {Contact} = db
  let allContacts = [];
  ['to', 'from', 'bcc', 'cc'].forEach((field) => {
    allContacts = allContacts.concat(messageValues[field])
  })

  const meaningfulContacts = allContacts.filter(c => isContactMeaningful(c));
  const contactsDataById = new Map()
  meaningfulContacts.forEach(c => {
    const id = Contact.hash(c)
    const cdata = {
      id,
      name: c.name,
      email: c.email,
      accountId: messageValues.accountId,
    }
    contactsDataById.set(id, cdata)
  })

  const existingContacts = await Contact.findAll({
    where: {
      id: Array.from(contactsDataById.keys()),
    },
  })

  for (const c of contactsDataById.values()) {
    const existing = existingContacts.find(({id}) => id === c.id);

    if (!existing) {
      Contact.create(c).catch(Sequelize.ValidationError, (err) => {
        if (err.name !== "SequelizeUniqueConstraintError") {
          logger.warn('Unknown error inserting contact', err);
          throw err;
        } else {
          // Another message with the same contact was processing concurrently,
          // and beat us to inserting. Since contacts are never deleted within
          // an account, we can safely assume that we can perform an update
          // instead.
          Contact.find({where: {id: c.id}}).then(
            (row) => { row.update(c) });
        }
      });
    } else {
      existing.update(c);
    }
  }
}

module.exports = extractContacts
