const _ = require('underscore')
const os = require('os');
const fs = require('fs');
const path = require('path')
const mkdirp = require('mkdirp');
const detectThread = require('./detect-thread');
const extractFiles = require('./extract-files');
const extractContacts = require('./extract-contacts');
const MessageFactory = require('../shared/message-factory')
const LocalDatabaseConnector = require('../shared/local-database-connector');


const MAX_QUEUE_LENGTH = 500
const PROCESSING_DELAY = 0

class MessageProcessor {

  constructor() {
    // The queue is a chain of Promises
    this._queue = Promise.resolve()
    this._queueLength = 0
  }

  queueLength() {
    return this._queueLength
  }

  queueIsFull() {
    return this._queueLength >= MAX_QUEUE_LENGTH
  }

  /**
   * @returns Promise that resolves when message has been processed
   * This promise will never reject, given that this function is meant to be
   * called as a fire and forget operation
   * If message processing fails, we will register the failure in the folder
   * syncState
   */
  queueMessageForProcessing({accountId, folderId, imapMessage, struct, desiredParts}) {
    return new Promise((resolve) => {
      this._queueLength++
      this._queue = this._queue.then(async () => {
        await this._processMessage({accountId, folderId, imapMessage, struct, desiredParts})
        this._queueLength--

        // To save memory, we reset the Promise chain if the queue reaches a
        // length of 0, otherwise we will continue referencing the entire chain
        // of promises that came before
        if (this._queueLength === 0) {
          this._queue = Promise.resolve()
        }
        resolve()

        // Throttle message processing to meter cpu usage
        await new Promise(r => setTimeout(r, PROCESSING_DELAY))
      })
    })
  }

  async _processMessage({accountId, folderId, imapMessage, struct, desiredParts}) {
    const db = await LocalDatabaseConnector.forAccount(accountId);
    const {Message, Folder} = db
    const folder = await Folder.findById(folderId)
    try {
      const messageValues = await MessageFactory.parseFromImap(imapMessage, desiredParts, {
        db,
        folder,
        accountId,
      });
      const existingMessage = await Message.find({where: {id: messageValues.id}});
      let processedMessage;
      if (existingMessage) {
        // TODO: optimize to not do a full message parse for existing messages
        processedMessage = await this._processExistingMessage(existingMessage, messageValues, struct)
      } else {
        processedMessage = await this._processNewMessage(messageValues, struct)
      }
      console.log(`🔃 ✉️ "${messageValues.subject}" - ${messageValues.date}`)
      return processedMessage
    } catch (err) {
      console.error(`FetchMessagesInFolder: Could not build message`, {
        err,
        imapMessage,
        desiredParts,
      })

      // Keep track of uids we failed to fetch
      const {failedUIDs = []} = folder.syncState
      const {uid} = imapMessage.attributes
      if (uid) {
        await folder.updateSyncState({failedUIDs: _.uniq(failedUIDs.concat([uid]))})
      }

      // Save parse errors for future debugging
      const outJSON = JSON.stringify({imapMessage, desiredParts, result: {}});
      const outDir = path.join(os.tmpdir(), "k2-parse-errors", folder.name)
      const outFile = path.join(outDir, imapMessage.attributes.uid.toString());
      mkdirp.sync(outDir);
      fs.writeFileSync(outFile, outJSON);
      return null
    }
  }

  async _processNewMessage(message, struct) {
    const {accountId} = message;
    const db = await LocalDatabaseConnector.forAccount(accountId);
    const {Message} = db

    const existingMessage = await Message.findById(message.id)
    if (existingMessage) {
      // This is an extremely rare case when 2 or more /new/ messages with
      // the exact same headers were queued for creation (same subject,
      // participants, timestamp, and message-id header). In this case, we
      // will ignore it and report the error
      console.warn('MessageProcessor: Encountered 2 new messages with the same id', {message})
      return null
    }
    const thread = await detectThread({db, message});
    message.threadId = thread.id;
    const createdMessage = await Message.create(message);

    if (message.labels) {
      await createdMessage.addLabels(message.labels)
      // Note that the labels aren't officially added until save() is called later
    }

    await extractFiles({db, message, struct});
    await extractContacts({db, message});
    createdMessage.isProcessed = true;
    await createdMessage.save()
    return createdMessage
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
  async _processExistingMessage(existingMessage, parsedMessage, struct) {
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
      await extractFiles({db, message: existingMessage, struct});
      await extractContacts({db, message: existingMessage});
      existingMessage.isProcessed = true;
    } else {
      if (!thread) {
        throw new Error(`Existing processed message ${existingMessage.id} doesn't have thread`)
      }
    }

    await existingMessage.save();
    await thread.updateLabelsAndFolders();
    return existingMessage
  }
}

module.exports = new MessageProcessor()
