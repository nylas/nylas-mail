const {DatabaseConnector, NylasError} = require(`nylas-core`)
const {processors} = require('./processors')

global.Promise = require('bluebird');
global.NylasError = NylasError;

// List of the attributes of Message that the processor should be allowed to change.
// The message may move between folders, get starred, etc. while it's being
// processed, and it shouldn't overwrite changes to those fields.
const MessageAttributes = ['body', 'processed', 'to', 'from', 'cc', 'bcc', 'snippet']
const MessageProcessorVersion = 1;

function runPipeline({db, accountId, message}) {
  return processors.reduce((prevPromise, processor) => (
    prevPromise.then((prevMessage) => {
      const processed = processor({message: prevMessage, accountId, db});
      if (!(processed instanceof Promise)) {
        throw new Error(`processor ${processor} did not return a promise.`)
      }
      return processed.then((nextMessage) => {
        if (!nextMessage.body) {
          throw new Error("processor did not resolve with a valid message object.")
        }
        return Promise.resolve(nextMessage);
      })
    })
  ), Promise.resolve(message))
}

function saveMessage(message) {
  message.processed = MessageProcessorVersion;
  return message.save({
    fields: MessageAttributes,
  });
}

function processMessage({messageId, accountId}) {
  DatabaseConnector.forAccount(accountId)
  .then((db) => {
    const {Message} = db
    Message.find({where: {id: messageId}}).then((message) =>
      runPipeline({db, accountId, message})
      .then((processedMessage) => saveMessage(processedMessage))
      .catch((err) =>
        console.error(`MessageProcessor Failed: ${err} ${err.stack}`)
      )
    )
    .catch((err) =>
      console.error(`MessageProcessor: Couldn't find message id ${messageId} in accountId: ${accountId}: ${err}`)
    )
  })
}

module.exports = {
  processMessage,
}
