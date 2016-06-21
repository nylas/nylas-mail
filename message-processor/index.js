const DatabaseConnectionFactory = require(`${__base}/core/database-connection-factory`)
const {processors} = require('./processors')

// List of the attributes of Message that the processor should b allowed to change.
// The message may move between folders, get starred, etc. while it's being
// processed, and it shouldn't overwrite changes to those fields.
const MessageAttributes = ['body', 'processed']
const MessageProcessorVersion = 1;

function runPipeline(message) {
  return processors.reduce((prevPromise, processor) => {
    return prevPromise.then((msg) => processor(msg))
  }, Promise.resolve(message))
}

function processMessage({messageId, accountId}) {
  DatabaseConnectionFactory.forAccount(accountId).then((db) =>
    db.Message.find({where: {id: messageId}}).then((message) =>
      runPipeline(message)
      .then((transformedMessage) => {
        transformedMessage.processed = MessageProcessorVersion;
        return transformedMessage.save({
          fields: MessageAttributes,
        });
      })
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
