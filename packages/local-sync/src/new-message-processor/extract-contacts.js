
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
  const {Contact} = db
  let allContacts = [];
  ['to', 'from', 'bcc', 'cc'].forEach((field) => {
    allContacts = allContacts.concat(message[field])
  })

  const meaningfulContacts = allContacts.filter(c => isContactMeaningful(c));
  const contactsDataById = new Map()
  meaningfulContacts.forEach(c => {
    const id = Contact.hash(c)
    const cdata = {
      id,
      name: c.name,
      email: c.email,
      accountId: message.accountId,
    }
    contactsDataById.set(id, cdata)
  })
  const existingContacts = await Contact.findAll({
    where: {
      id: Array.from(contactsDataById.keys()),
    },
  })

  for (const c of contactsDataById.values()) {
    const existing = existingContacts.find(({id}) => id === c.id)
    if (!existing) {
      await Contact.create(c)
    } else {
      const updateRequired = (c.name !== existing.name);
      if (updateRequired) {
        await existing.update(c)
      }
    }
  }

  return message;
}

module.exports = extractContacts
