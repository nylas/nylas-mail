const {PubsubConnector, DatabaseConnector, NylasError} = require(`nylas-core`)
const {processors} = require('./processors')

global.Promise = require('bluebird');
global.NylasError = NylasError;

// List of the attributes of Message that the processor should be allowed to change.
// The message may move between folders, get starred, etc. while it's being
// processed, and it shouldn't overwrite changes to those fields.
const MessageAttributes = ['body', 'processed', 'to', 'from', 'cc', 'replyTo', 'bcc', 'snippet', 'threadId']
const MessageProcessorVersion = 1;

function runPipeline({db, accountId, message}) {
  console.log(`Processing message ${message.id}`)
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

function dequeueJob() {
  const conn = PubsubConnector.buildClient()
  conn.brpopAsync('message-processor-queue', 10).then((item) => {
    if (!item) {
      return dequeueJob();
    }

    let json = null;
    try {
      json = JSON.parse(item[1]);
    } catch (error) {
      console.error(`MessageProcessor Failed: Found invalid JSON item in queue: ${item}`)
      return dequeueJob();
    }
    const {messageId, accountId} = json;

    DatabaseConnector.forAccount(accountId).then((db) =>
      db.Message.find({
        where: {id: messageId},
        include: [{model: db.Folder}, {model: db.Label}],
      }).then((message) => {
        if (!message) {
          return Promise.reject(new Error(`Message not found (${messageId}). Maybe account was deleted?`))
        }
        return runPipeline({db, accountId, message}).then((processedMessage) =>
          saveMessage(processedMessage)
        ).catch((err) =>
          console.error(`MessageProcessor Failed: ${err} ${err.stack}`)
        )
      })
    ).finally(() => {
      dequeueJob()
    });

    return null;
  })
}

dequeueJob();
