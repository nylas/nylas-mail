const Metrics = require(`nylas-metrics`)
Metrics.startCapturing('nylas-k2-message-processor')

const {PubsubConnector, DatabaseConnector, Logger} = require(`nylas-core`)
const {processors} = require('./processors')

global.Metrics = Metrics
global.Logger = Logger.createLogger('nylas-k2-message-processor')

const onUnhandledError = (err) => {
  global.Logger.fatal(err, 'Unhandled error')
  global.Metrics.reportError(err)
}
process.on('uncaughtException', onUnhandledError)
process.on('unhandledRejection', onUnhandledError)

// List of the attributes of Message that the processor should be allowed to change.
// The message may move between folders, get starred, etc. while it's being
// processed, and it shouldn't overwrite changes to those fields.
const MessageAttributes = ['body', 'processed', 'to', 'from', 'cc', 'replyTo', 'bcc', 'snippet', 'threadId']
const MessageProcessorVersion = 1;

const redis = PubsubConnector.buildClient();

function runPipeline({db, accountId, message, logger}) {
  logger.info(`MessageProcessor: Processing message`)
  return processors.reduce((prevPromise, processor) => (
    prevPromise.then((prevMessage) => {
      const processed = processor({message: prevMessage, accountId, db, logger});
      return Promise.resolve(processed)
      .then((nextMessage) => {
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
  redis.brpopAsync('message-processor-queue', 10).then((item) => {
    if (!item) {
      return dequeueJob();
    }

    let json = null;
    try {
      json = JSON.parse(item[1]);
    } catch (error) {
      global.Logger.error({item}, `MessageProcessor: Found invalid JSON item in queue`)
      return dequeueJob();
    }
    const {messageId, accountId} = json;
    const logger = global.Logger.forAccount({id: accountId}).child({message_id: messageId})

    DatabaseConnector.forAccount(accountId).then((db) => {
      return db.Message.find({
        where: {id: messageId},
        include: [{model: db.Folder}, {model: db.Label}],
      }).then((message) => {
        if (!message) {
          return Promise.reject(new Error(`Message not found (${messageId}). Maybe account was deleted?`))
        }
        return runPipeline({db, accountId, message, logger}).then((processedMessage) =>
          saveMessage(processedMessage)
        ).catch((err) =>
          logger.error(err, `MessageProcessor: Failed`)
        )
      })
    })
    .finally(() => {
      dequeueJob()
    });

    return null;
  })
}

dequeueJob();
