const detectThread = require('./detect-thread');
const extractFiles = require('./extract-files');
const extractContacts = require('./extract-contacts');
const LocalDatabaseConnector = require('../shared/local-database-connector');

const Queue = require('promise-queue');
const queue = new Queue(1, Infinity);

function processNewMessage(message, imapMessage) {
  queue.add(async () => {
    const {accountId} = message;
    const logger = global.Logger.forAccount({id: accountId}).child({message})
    const db = await LocalDatabaseConnector.forAccount(accountId);
    const {Message} = db

    try {
      const existingMessage = await Message.findById(message.id)
      if (existingMessage) {
        // This is an extremely rare case when 2 or more /new/ messages with
        // the exact same headers were queued for creation (same subject,
        // participants, timestamp, and message-id header). In this case, we
        // will ignore it and report the error
        logger.warn({message}, 'MessageProcessor: Encountered 2 new messages with the same id')
        return
      }
      const thread = await detectThread({db, message});
      message.threadId = thread.id;
      await Message.create(message);
      await extractFiles({db, message, imapMessage});
      await extractContacts({db, message});
      console.log(`🔃 ✉️ "${message.subject}"`)
      // logger.info({
      //   message_id: message.id,
      //   uid: message.folderImapUID,
      // }, `MessageProcessor: Created and processed message`);
    } catch (err) {
      logger.error(err, `MessageProcessor: Failed`);
    }
  });
}

module.exports = {processNewMessage}
