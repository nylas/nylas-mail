
class ContactProcessor {

  verified(contact) {
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

  emptyContact(Contact, options = {}, accountId) {
    options.accountId = accountId
    return Contact.create(options)
  }

  findOrCreateByContactId(Contact, contact, accountId) {
    return Contact.find({where: {email: contact.email}})
    .then((contactDb) => {
      return contactDb || this.emptyContact(Contact, contact, accountId)
    })
  }


  processMessage({db, message, logger}) {
    const {Contact} = db;
    this.logger = logger

    let allContacts = []
    const fields = ['to', 'from', 'bcc', 'cc']
    fields.forEach((field) => {
      allContacts = allContacts.concat(message[field])
    })
    const filtered = allContacts.filter(this.verified)
    const contactPromises = filtered.map((contact) => {
      return this.findOrCreateByContactId(Contact, contact, message.accountId)
    })

    return Promise.all(contactPromises)
    .then(() => {
      return message
    })
  }
}

const processor = new ContactProcessor()

module.exports = {
  order: 3,
  processMessage: processor.processMessage.bind(processor),
}
