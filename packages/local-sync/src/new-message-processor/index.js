const detectThread = require('./detect-thread');
const extractFiles = require('./extract-files');
const extractContacts = require('./extract-contacts');
const LocalDatabaseConnector = require('../shared/local-database-connector');

async function processNewMessage(message, imapMessage) {
  const {accountId} = message;
  const logger = global.Logger.forAccount({id: accountId}).child({message})
  const db = await LocalDatabaseConnector.forAccount(accountId);
  const {Message} = db

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
  const createdMessage = await Message.create(message);

  if (message.labels) {
    await createdMessage.addLabels(message.labels)
    // Note that the labels aren't officially added until save() is called later
  }

  await extractFiles({db, message, imapMessage});
  await extractContacts({db, message});
  createdMessage.isProcessed = true;
  await createdMessage.save()
}

/**
 * When we send a message we store an incomplete copy in the local
 * database while we wait for the sync loop to discover the actually
 * delivered one. We store this to keep track of our delivered state and
 * to ensure it's in the sent folder.
 *
 * We also get already processed messages because they may have had their
 * folders or labels changed or had some other property updated with them.
 *
 * It'll have the basic ID, but no thread, labels, etc.
 */
async function processExistingMessage(existingMessage, parsedMessage, rawIMAPMessage) {
  const {accountId} = parsedMessage;
  const db = await LocalDatabaseConnector.forAccount(accountId);
  await existingMessage.update(parsedMessage);
  if (parsedMessage.labels && parsedMessage.labels.length > 0) {
    await existingMessage.setLabels(parsedMessage.labels)
  }
  let thread = await existingMessage.getThread();
  if (!existingMessage.isProcessed) {
    if (!thread) {
      thread = await detectThread({db, message: parsedMessage});
      existingMessage.threadId = thread.id;
    }
    await extractFiles({db, message: existingMessage, imapMessage: rawIMAPMessage});
    await extractContacts({db, message: existingMessage});
    existingMessage.isProcessed = true;
    await existingMessage.save();
  } else {
    if (!thread) {
      throw new Error(`Existing processed message ${existingMessage.id} doesn't have thread`)
    }
  }
  await thread.updateLabelsAndFolders();
}

module.exports = {processNewMessage, processExistingMessage}
