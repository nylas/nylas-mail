const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)
const processors = require('./processors')

function createMessage({headers, body, attributes, hash, db}) {
  const {Message} = db
  return Message.create({
    hash: hash,
    unread: attributes.flags.includes('\\Unseen'),
    starred: attributes.flags.includes('\\Flagged'),
    date: attributes.date,
    headers: headers,
    body: body,
  })
}

function runPipeline(message) {
  return processors.reduce((prevPromise, processor) => {
    return prevPromise.then((msg) => processor(msg))
  }, Promise.resolve(message))
}

function processMessage({headers, body, attributes, hash, accountId}) {
  return DatabaseConnectionFactory.forAccount(accountId)
  .then((db) => createMessage({headers, body, attributes, hash, db}))
  .then((message) => runPipeline(message))
  .then((processedMessage) => processedMessage)
  .catch((err) => console.log('oh no'))
}

module.exports = {
  processMessage,
}
