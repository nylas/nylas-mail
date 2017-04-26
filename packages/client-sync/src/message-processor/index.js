const _ = require('underscore')
const os = require('os');
const fs = require('fs');
const path = require('path')
const mkdirp = require('mkdirp');
const detectThread = require('./detect-thread');
const extractFiles = require('./extract-files');
const extractContacts = require('./extract-contacts');
const {MessageUtils, TrackingUtils} = require('isomorphic-core');
const LocalDatabaseConnector = require('../shared/local-database-connector');
const {AccountStore, BatteryStatusManager} = require('nylas-exports');
const SyncActivity = require('../shared/sync-activity').default;

const MAX_QUEUE_LENGTH = 500
// These CPU limits only apply when we're actually throttling. We don't
// throttle for new mail, the first 500 threads, or for specific sets of
// UIDs (e.g. during search for unsynced UIDs). Thus, we're essentially only
// throttling when syncing the historical archive.
const MAX_CPU_USE_ON_AC = 0.5;
const MAX_CPU_USE_ON_BATTERY = 0.05;
const MAX_CHUNK_SIZE = 1;

class MessageProcessor {

  constructor() {
    // The queue is a chain of Promises
    this._queue = Promise.resolve()
    this._queueLength = 0
    this._currentChunkSize = 0
    this._currentChunkStart = Date.now();
  }

  queueLength() {
    return this._queueLength
  }

  queueIsFull() {
    return this._queueLength >= MAX_QUEUE_LENGTH
  }

  _maxCPUForProcessing() {
    if (BatteryStatusManager.isBatteryCharging()) {
      return MAX_CPU_USE_ON_AC;
    }
    return MAX_CPU_USE_ON_BATTERY;
  }

  _computeThrottlingTimeout() {
    const timeSliceMs = Date.now() - this._currentChunkStart;
    const maxCPU = this._maxCPUForProcessing();
    return (timeSliceMs * (1.0 / maxCPU)) - timeSliceMs;
  }

  /**
   * @returns Promise that resolves when message has been processed. This
   * promise will never reject. If message processing fails, we will register
   * the failure in the folder syncState.
   */
  queueMessageForProcessing({accountId, folderId, imapMessage, struct, desiredParts, throttle = true} = {}) {
    return new Promise(async (resolve) => {
      let logger;
      let folder;
      try {
        const accountDb = await LocalDatabaseConnector.forShared()
        const account = await accountDb.Account.findById(accountId)
        const db = await LocalDatabaseConnector.forAccount(accountId);
        const {Folder} = db
        folder = await Folder.findById(folderId)
        logger = global.Logger.forAccount(account)

        this._queueLength++
        this._queue = this._queue.then(async () => {
          if (this._currentChunkSize === 0) {
            this._currentChunkStart = Date.now();
          }
          this._currentChunkSize++;

          await this._processMessage({db, accountId, folder, imapMessage, struct, desiredParts, logger})
          this._queueLength--

          // Throttle message processing to meter cpu usage
          if (this._currentChunkSize === MAX_CHUNK_SIZE) {
            if (throttle) {
              await new Promise(r => setTimeout(r, this._computeThrottlingTimeout()));
            }
            this._currentChunkSize = 0;
          }

          // To save memory, we reset the Promise chain if the queue reaches a
          // length of 0, otherwise we will continue referencing the entire chain
          // of promises that came before
          if (this._queueLength === 0) {
            this._queue = Promise.resolve()
          }
          resolve();
        });
      } catch (err) {
        if (logger && folder) {
          await this._onError({imapMessage, desiredParts, folder, err, logger});
        } else {
          NylasEnv.reportError(err);
        }
        resolve();
      }
    })
  }

  async _processMessage({db, accountId, folder, imapMessage, struct, desiredParts, logger}) {
    try {
      const {Message, Folder, Label} = db;
      const messageValues = await MessageUtils.parseFromImap(imapMessage, desiredParts, {
        db,
        folder,
        accountId,
      });

      /**
       * When we send messages, Gmail will automatically stuff messages in
       * the sent folder that contain open & link tracking data. While we
       * will eventually clean that up, if the send takes a while to
       * multiple people (due to attachments) it's possible that we'll
       * sync that recently sent message. If this happens, we want to
       * ensure that no open and link tracking data is included.
       */
      if (AccountStore.isMyEmail(messageValues.from.map(f => f.email))) {
        messageValues.body = TrackingUtils.stripTrackingLinksFromBody(messageValues.body)
      }

      const existingMessage = await Message.findById(messageValues.id, {
        include: [{model: Folder, as: 'folder'}, {model: Label, as: 'labels'}],
      });
      let processedMessage;
      if (existingMessage) {
        // TODO: optimize to not do a full message parse for existing messages
        processedMessage = await this._processExistingMessage({
          logger,
          struct,
          messageValues,
          existingMessage,
        })
      } else {
        processedMessage = await this._processNewMessage({
          logger,
          struct,
          messageValues,
        })
      }

      // Inflate the serialized oldestProcessedDate value, if it exists
      let oldestProcessedDate;
      if (folder.syncState && folder.syncState.oldestProcessedDate) {
        oldestProcessedDate = new Date(folder.syncState.oldestProcessedDate);
      }
      const justProcessedDate = messageValues.date ? new Date(messageValues.date) : new Date()

      // Update the oldestProcessedDate if:
      //   a) justProcessedDate is after the year 1980. We don't want to base this
      //      off of messages with borked 1970 dates.
      // AND
      //   b) i) We haven't set oldestProcessedDate yet
      //     OR
      //      ii) justProcessedDate is before oldestProcessedDate and in a different
      //          month. (We only use this to update the sync status in Nylas Mail,
      //          which uses month precision. Updating a folder's syncState triggers
      //          many re-renders in Nylas Mail, so we only do it as necessary.)
      if (justProcessedDate > new Date("1980") && (
            !oldestProcessedDate || (
              (justProcessedDate.getMonth() !== oldestProcessedDate.getMonth() ||
                justProcessedDate.getFullYear() !== oldestProcessedDate.getFullYear()) &&
              justProcessedDate < oldestProcessedDate))) {
        await folder.updateSyncState({oldestProcessedDate: justProcessedDate})
      }

      const activity = `🔃 ✉️ (${folder.name}) "${messageValues.subject}" - ${messageValues.date}`
      logger.log(activity)
      SyncActivity.reportSyncActivity(accountId, activity)
      return processedMessage
    } catch (err) {
      await this._onError({imapMessage, desiredParts, folder, err, logger});
      return null
    }
  }

  async _onError({imapMessage, desiredParts, folder, err, logger}) {
    logger.error(`MessageProcessor: Could not build message`, {
      err,
      imapMessage,
      desiredParts,
    })
    const fingerprint = ["{{ default }}", "message processor", err.message];
    NylasEnv.reportError(err, {fingerprint,
      rateLimit: {
        ratePerHour: 30,
        key: `MessageProcessorError:${err.message}`,
      },
    })

    // Keep track of uids we failed to fetch
    const {failedUIDs = []} = folder.syncState
    const {uid} = imapMessage.attributes
    if (uid) {
      await folder.updateSyncState({failedUIDs: _.uniq(failedUIDs.concat([uid]))})
    }

    // Save parse errors for future debugging
    if (process.env.NYLAS_DEBUG) {
      const outJSON = JSON.stringify({imapMessage, desiredParts, result: {}});
      const outDir = path.join(os.tmpdir(), "k2-parse-errors", folder.name)
      const outFile = path.join(outDir, imapMessage.attributes.uid.toString());
      mkdirp.sync(outDir);
      fs.writeFileSync(outFile, outJSON);
    }
  }

  // Replaces ["<rfc2822messageid>", ...] with [[object Reference], ...]
  // Creates references that do not yet exist, and adds the correct
  // associations as well
  async _addReferences(db, message, thread, references) {
    const {Reference} = db;

    let existingReferences = [];
    if (references.length > 0) {
      existingReferences = await Reference.findAll({
        where: {
          rfc2822MessageId: references,
        },
      });
    }

    const refByMessageId = {};
    for (const ref of existingReferences) {
      refByMessageId[ref.rfc2822MessageId] = ref;
    }
    for (const mid of references) {
      if (!refByMessageId[mid]) {
        refByMessageId[mid] = await Reference.create({rfc2822MessageId: mid, threadId: thread.id});
      }
    }

    const referencesInstances = references.map(mid => refByMessageId[mid]);
    await message.addReferences(referencesInstances);
    message.referencesOrder = referencesInstances.map(ref => ref.id);
    await thread.addReferences(referencesInstances);
  }

  async _processNewMessage({messageValues, struct, logger = console} = {}) {
    const {accountId} = messageValues;
    const db = await LocalDatabaseConnector.forAccount(accountId);
    const {Message} = db

    const thread = await detectThread({db, messageValues});
    messageValues.threadId = thread.id;
    // The way that sequelize initializes objects doesn't guarantee that the
    // object will have a value for `id` before initializing the `body` field
    // (which we now depend on). By using `build` instead of `create`, we can
    // initialize an object with just the `id` field and then use `update` to
    // initialize the remaining fields and save the object to the database.
    const createdMessage = Message.build({id: messageValues.id});
    await createdMessage.update(messageValues);

    if (messageValues.labels) {
      await createdMessage.addLabels(messageValues.labels)
      // Note that the labels aren't officially associated until save() is called later
    }

    await this._addReferences(db, createdMessage, thread, messageValues.references);

    // TODO: need to delete dangling references somewhere (maybe at the
    // end of the sync loop?)

    const files = await extractFiles({db, messageValues, struct});
    // Don't count inline images (files with contentIds) as attachments
    if (files.some(f => !f.contentId) && !thread.hasAttachments) {
      thread.hasAttachments = true;
      await thread.save();
    }
    await extractContacts({db, messageValues, logger});

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
   * It'll have the basic ID, but no thread, labels, etc.
   *
   * We also get already processed messages because they may have had their
   * folders or labels changed or had some other property updated with them,
   * or because we interrupted the sync loop before the message was fully
   * processed.
   */
  async _processExistingMessage({existingMessage, messageValues, struct} = {}) {
    const {accountId} = messageValues;
    const db = await LocalDatabaseConnector.forAccount(accountId);

    /**
     * There should never be a reason to update the body of a message
     * already in the database.
     *
     * When we use link/open tracking on Gmail, we optimistically create a
     * Message whose body is stripped of tracking pixels (so you don't
     * self trigger). Since it takes time to delete the old draft on Gmail
     * & restuff, it's possible to sync a message with a non-stripped body
     * (which would cause you to self-trigger)). This prevents this from
     * happening.
     */
    const newMessageWithoutBody = _.clone(messageValues)
    delete newMessageWithoutBody.body;
    await existingMessage.update(newMessageWithoutBody);
    if (messageValues.labels && messageValues.labels.length > 0) {
      await existingMessage.setLabels(messageValues.labels)
    }

    let thread = await existingMessage.getThread({
      include: [{model: db.Folder, as: 'folders'}, {model: db.Label, as: 'labels'}],
    });
    if (!existingMessage.isProcessed) {
      if (!thread) {
        thread = await detectThread({db, messageValues});
        existingMessage.threadId = thread.id;
      } else {
        await thread.updateFromMessages({db, messages: [existingMessage]})
      }
      await this._addReferences(db, existingMessage, thread, messageValues.references);
      const files = await extractFiles({db, messageValues: existingMessage, struct});
      // Don't count inline images (files with contentIds) as attachments
      if (files.some(f => !f.contentId) && !thread.hasAttachments) {
        thread.hasAttachments = true;
        await thread.save();
      }
      await extractContacts({db, messageValues: existingMessage});
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
