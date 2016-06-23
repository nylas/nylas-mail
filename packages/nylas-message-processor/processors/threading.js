const {DatabaseConnectionFactory} = require('nylas-core')

function processMessage({message, accountId}) {
  return DatabaseConnectionFactory.forAccount(accountId)
  .then((db) => addMessageToThread({db, accountId, message}))
  .then((thread) => {
    thread.addMessage(message)
    message.setThread(thread)
    return message
  })
}

function addMessageToThread({db, accountId, message}) {
  const {Thread, Message} = db
  if (message.threadId) {
    return Thread.find({where: {threadId: message.threadId}})
  }
  return matchThread({db, accountId, message})
  .then((thread) => (thread))
}

function matchThread({db, accountId, message}) {
  const {Thread} = db

  // TODO: Add once we have some test data with this header
  /*
  if (message.headers['in-reply-to']) {
    return getThreadFromHeader() // Doesn't exist yet
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
  */
  return Thread.create({
    subject: message.subject,
    cleanedSubject: cleanSubject(message.subject),
  })
}

function cleanSubject(subject) {
  if (subject === null) {
    return ""
  }
  const regex = new RegExp(/^((re|fw|fwd|aw|wg|undeliverable|undelivered):\s*)+/ig)
  const cleanedSubject = subject.replace(regex, (match) => "")
  return cleanedSubject
}

// TODO: Incorporate this more elaborate threading algorithm
/*
function fetchCorrespondingThread({db, accountId, message}) {
  const cleanedSubject = cleanSubject(message.subject)
  return getThreads({db, message, cleanedSubject})
  .then((threads) => {
    return findCorrespondingThread({message, threads})
  })
}

function getThreads({db, message, cleanedSubject}) {
  const {Thread} = db
  return Thread.findAll({
    where: {
      threadId: message.headers.threadId,
      cleanedSubject: cleanedSubject,
    },
    order: [
      ['id', 'DESC']
    ],
  })
}

function findCorrespondingThread({message, threads}) {
  for (const thread of threads) {
    for (const match of thread.messages) {
      // Ignore BCC
      const {matchEmails, messageEmails} = removeBccParticipants({message, match})

      // A thread is probably related if it has more than two common participants
      const intersectingParticipants = getIntersectingParticipants({messageEmails, matchEmails})
      if (intersectingParticipants.length >= 2) {
        if (thread.messages.length >= MAX_THREAD_LENGTH)
          break
        return match.thread
      }

      // Handle case for self-sent emails
      if (!message.from || !message.to)
        return
      if (isSentToSelf({message, match})) {
        if (thread.messages.length >= MAX_THREAD_LENGTH)
          break
        return match.thread
      }
    }
  }
}

function removeBccParticipants({message, match}) {
  const matchBcc = match.bcc ? match.bcc : []
  const messageBcc = message.bcc ? message.bcc : []
  let matchEmails = match.participants.filter((participant) => {
    return matchBcc.find(bcc => bcc === participant)
  })
  matchEmails.map((email) => {
    return email[1]
  })
  let messageEmails = message.participants.filter((participant) => {
    return messageBcc.find(bcc => bcc === participant)
  })
  messageEmails.map((email) => {
    return email[1]
  })
  return {messageEmails, matchEmails}
}

function getIntersectingParticipants({messageEmails, matchEmails}) {
  const matchParticipants = new Set(matchEmails)
  const messageParticipants = new Set(messageEmails)
  const intersectingParticipants = new Set([...matchParticipants]
    .filter(participant => messageParticipants.has(participant)))
  return intersectingParticipants
}

function isSentToSelf({message, match}) {
  const matchFrom = match.from.map((participant) => {
    return participant[1]
  })
  const matchTo = match.to.map((participant) => {
    return participant[1]
  })
  const messageFrom = message.from.map((participant) => {
    return participant[1]
  })
  const messageTo = message.to.map((participant) => {
    return participant[1]
  })

  return (messageTo.length === 1 &&
    messageFrom === messageTo &&
    matchFrom === matchTo &&
    messageTo === matchFrom)
}
*/

module.exports = {
  order: 1,
  processMessage,
}
