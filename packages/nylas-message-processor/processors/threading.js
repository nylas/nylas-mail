const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)

function processMessage({message, accountId}) {
  return DatabaseConnectionFactory.forAccount(accountId)
  .then((db) => addMessageToThread({db, accountId, message}))
  .then((thread) => {
    thread.setMessages([message])
    return message
  })
}

function addMessageToThread({db, accountId, message}) {
  const {Thread, Message} = db
  if (message.threadId) {
    return Thread.findOne({
      where: {
        threadId: message.threadId,
      }
    })
  }
  return matchThread({db, accountId, message})
  .then((thread) => {
    if (thread) {
      return thread
    }
    return Thread.create({
      subject: message.subject,
      cleanedSubject: cleanSubject(message.subject),
    })
  })
}

function matchThread({db, accountId, message}) {
  if (message.headers.inReplyTo) {
    return getThreadFromHeader()
    .then((thread) => {
      if (thread) {
        return thread
      }
      return Thread.create({
        subject: message.subject,
        cleanedSubject: cleanSubject(message.subject),
      })
    })
  }
  return Thread.create({
    subject: message.subject,
    cleanedSubject: cleanSubject(message.subject),
  })
}

module.exports = {
  order: 0,
  processMessage,
}
