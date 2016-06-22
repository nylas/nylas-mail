const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)
const {processors} = require('./processors')

// List of the attributes of Message that the processor should be allowed to change.
// The message may move between folders, get starred, etc. while it's being
// processed, and it shouldn't overwrite changes to those fields.
const MessageAttributes = ['body', 'processed']
const MessageProcessorVersion = 1;


function runPipeline(accountId, message) {
  return processors.reduce((prevPromise, processor) => (
    prevPromise.then((msg) => processor({message: msg, accountId}))
  ), Promise.resolve(message))
}

function saveMessage(message) {
  message.processed = MessageProcessorVersion;
  return message.save({
    fields: MessageAttributes,
  });
}

function processMessage({messageId, accountId}) {
  DatabaseConnectionFactory.forAccount(accountId)
  .then(({Message}) =>
    Message.find({where: {id: messageId}}).then((message) =>
      runPipeline(accountId, message)
      .then((processedMessage) => saveMessage(processedMessage))
      .catch((err) =>
        console.error(`MessageProcessor Failed: ${err}`)
      )
    )
    .catch((err) =>
      console.error(`MessageProcessor: Couldn't find message id ${messageId} in accountId: ${accountId}: ${err}`)
    )
  )
}

module.exports = {
  processMessage,
}
