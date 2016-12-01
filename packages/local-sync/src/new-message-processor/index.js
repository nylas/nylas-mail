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

    try {
      const thread = await detectThread({db, message});
      message.threadId = thread.id;
      await db.Message.create(message);
      await extractFiles({db, message, imapMessage});
      await extractContacts({db, message});
      logger.info({
        message_id: message.id,
        uid: message.folderImapUID,
      }, `MessageProcessor: Created and processed message`);
    } catch (err) {
      logger.error(err, `MessageProcessor: Failed`);
    }
  });
}

module.exports = {processNewMessage}
