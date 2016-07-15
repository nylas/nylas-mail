
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

  processMessage({db, message}) {
    const {Contact} = db;

    let allContacts = [];
    ['to', 'from', 'bcc', 'cc'].forEach((field) => {
      allContacts = allContacts.concat(message[field])
    })

    const verifiedContacts = allContacts.filter(this.verified);

    return db.sequelize.transaction((transaction) => {
      return Promise.all(verifiedContacts.map((contact) =>
        Contact.upsert({
          name: contact.name,
          email: contact.email,
          accountId: message.accountId,
        }, {
          transaction,
        })
      ))
    }).thenReturn(message)
  }
}

const processor = new ContactProcessor()

module.exports = {
  order: 3,
  processMessage: processor.processMessage.bind(processor),
}
