const _ = require('underscore');
const os = require('os');
const fs = require('fs');
const path = require('path')
const mkdirp = require('mkdirp');

const {PromiseUtils, IMAPConnection} = require('isomorphic-core');
const {Capabilities} = IMAPConnection;
const MessageFactory = require('../../shared/message-factory')
const {processNewMessage} = require('../../new-message-processor')

const MessageFlagAttributes = ['id', 'threadId', 'folderImapUID', 'unread', 'starred', 'folderImapXGMLabels']

const SHALLOW_SCAN_UID_COUNT = 1000;
const FETCH_MESSAGES_FIRST_COUNT = 100;
const FETCH_MESSAGES_COUNT = 200;

class FetchMessagesInFolder {
  constructor(folder, options, logger) {
    this._imap = null
    this._box = null
    this._db = null
    this._folder = folder;
    this._options = options;
    this._logger = logger.child({category_name: this._folder.name});
    if (!this._logger) {
      throw new Error("FetchMessagesInFolder requires a logger")
    }
    if (!this._folder) {
      throw new Error("FetchMessagesInFolder requires a category")
    }
  }

  description() {
    return `FetchMessagesInFolder (${this._folder.name} - ${this._folder.id})\n  Options: ${JSON.stringify(this._options)}`;
  }

  _getLowerBoundUID(count) {
    return count ? Math.max(1, this._box.uidnext - count) : 1;
  }

  async _recoverFromUIDInvalidity() {
    // UID invalidity means the server has asked us to delete all the UIDs for
    // this folder and start from scratch. Instead of deleting all the messages,
    // we just remove the category ID and UID. We may re-assign the same message
    // the same UID. Otherwise they're eventually garbage collected.
    const {Message} = this._db;
    await this._db.sequelize.transaction((transaction) =>
      Message.update({
        folderImapUID: null,
        folderId: null,
      }, {
        transaction: transaction,
        where: {
          folderId: this._folder.id,
        },
      })
    )
  }

  async _updateMessageAttributes(remoteUIDAttributes, localMessageAttributes) {
    const {sequelize, Label, Thread} = this._db;

    const messageAttributesMap = {};
    for (const msg of localMessageAttributes) {
      messageAttributesMap[msg.folderImapUID] = msg;
    }

    const createdUIDs = [];
    const messagesWithChangedFlags = [];
    const messagesWithChangedLabels = [];

    // Step 1: Identify changed messages and update their attributes in place

    const preloadedLabels = await Label.findAll();
    await PromiseUtils.each(Object.keys(remoteUIDAttributes), async (uid) => {
      const msg = messageAttributesMap[uid];
      const attrs = remoteUIDAttributes[uid];

      if (!msg) {
        createdUIDs.push(uid);
        return;
      }

      const unread = !attrs.flags.includes('\\Seen');
      const starred = attrs.flags.includes('\\Flagged');
      const xGmLabels = attrs['x-gm-labels'];
      const xGmLabelsJSON = xGmLabels ? JSON.stringify(xGmLabels) : null;

      if (msg.folderImapXGMLabels !== xGmLabelsJSON) {
        await msg.setLabelsFromXGM(xGmLabels, {Label, preloadedLabels})
        messagesWithChangedLabels.push(msg);
      }

      if (msg.unread !== unread || msg.starred !== starred) {
        msg.unread = unread;
        msg.starred = starred;
        messagesWithChangedFlags.push(msg);
      }
    })

    if (createdUIDs.length > 0) {
      this._logger.info({
        new_messages: createdUIDs.length,
      }, `FetchMessagesInFolder: found new messages. These will not be processed because we assume that they will be assigned uid = uidnext, and will be picked up in the next sync when we discover unseen messages.`);
    }

    // Step 2: If flags were changed, apply the changes to the corresponding
    // threads. We do this as a separate step so we can batch-load the threads.
    if (messagesWithChangedFlags.length > 0) {
      const threadIds = messagesWithChangedFlags.map(m => m.threadId);
      const threads = await Thread.findAll({where: {id: threadIds}});
      const threadsById = {};
      for (const thread of threads) {
        threadsById[thread.id] = thread;
      }
      for (const msg of messagesWithChangedFlags) {
        // unread = false, previous = true? Add -1 to unreadCount.
        // IMPORTANT: Relies on messages changed above not having been saved yet!
        threadsById[msg.threadId].unreadCount += msg.unread / 1 - msg.previous('unread') / 1;
        threadsById[msg.threadId].starredCount += msg.starred / 1 - msg.previous('starred') / 1;
      }
      await sequelize.transaction(async (transaction) => {
        await Promise.all(threads.map(t =>
          t.save({ fields: ['starredCount', 'unreadCount'], transaction })
        ));
      });
    }

    // Step 3: Persist the messages we've updated
    const messagesChanged = [].concat(messagesWithChangedFlags, messagesWithChangedLabels);
    await sequelize.transaction(async (transaction) => {
      await Promise.all(messagesChanged.map(m =>
        m.save({fields: MessageFlagAttributes, transaction})
      ))
    });

    // Step 4: If message labels were changed, retreive the impacted threads
    // and re-compute their labels. This is fairly expensive at the moment.
    if (messagesWithChangedLabels.length > 0) {
      const threadIds = messagesWithChangedLabels.map(m => m.threadId);
      const threads = await Thread.findAll({where: {id: threadIds}});
      threads.forEach((thread) => thread.updateLabelsAndFolders());
    }
  }

  async _removeDeletedMessages(remoteUIDAttributes, localMessageAttributes) {
    const {Message} = this._db;

    const removedUIDs = localMessageAttributes
    .filter(msg => !remoteUIDAttributes[msg.folderImapUID])
    .map(msg => msg.folderImapUID)

    if (removedUIDs.length === 0) {
      return;
    }

    this._logger.info({
      removed_messages: removedUIDs.length,
    }, `FetchMessagesInFolder: found messages no longer in the folder`)

    await this._db.sequelize.transaction((transaction) =>
       Message.update({
         folderImapUID: null,
         folderId: null,
       }, {
         transaction,
         where: {
           folderId: this._folder.id,
           folderImapUID: removedUIDs,
         },
       })
    );
  }

  _getDesiredMIMEParts(struct) {
    const desired = [];
    const available = [];
    const unseen = [struct];
    while (unseen.length > 0) {
      const part = unseen.shift();
      if (part instanceof Array) {
        unseen.push(...part);
      } else {
        const mimetype = `${part.type}/${part.subtype}`;
        available.push(mimetype);
        if (['text/plain', 'text/html', 'application/pgp-encrypted'].includes(mimetype)) {
          desired.push({
            id: part.partID,
            encoding: part.encoding,
            mimetype,
          });
        }
      }
    }

    if (desired.length === 0) {
      this._logger.warn({
        available_options: available.join(', '),
      }, `FetchMessagesInFolder: Could not find good part`)
    }

    return desired;
  }

  async _fetchMessagesAndQueueForProcessing(range) {
    const uidsByPart = {};

    await this._box.fetchEach(range, {struct: true}, ({attributes}) => {
      const desiredParts = this._getDesiredMIMEParts(attributes.struct);
      if (desiredParts.length === 0) {
        return;
      }
      const key = JSON.stringify(desiredParts);
      uidsByPart[key] = uidsByPart[key] || [];
      uidsByPart[key].push(attributes.uid);
    })

    await PromiseUtils.each(Object.keys(uidsByPart), (key) => {
      const uids = uidsByPart[key];
      const desiredParts = JSON.parse(key);
      const bodies = ['HEADER'].concat(desiredParts.map(p => p.id));

      this._logger.info({
        key,
        num_messages: uids.length,
      }, `FetchMessagesInFolder: Fetching parts for messages`)

      // note: the order of UIDs in the array doesn't matter, Gmail always
      // returns them in ascending (oldest => newest) order.

      return this._box.fetchEach(
        uids,
        {bodies, struct: true},
        (imapMessage) => this._processMessage(imapMessage, desiredParts)
      );
    });
  }

  async _processMessage(imapMessage, desiredParts) {
    const {Message} = this._db

    try {
      const messageValues = await MessageFactory.parseFromImap(imapMessage, desiredParts, {
        db: this._db,
        folder: this._folder,
        accountId: this._db.accountId,
      });
      const existingMessage = await Message.find({where: {id: messageValues.id}});

      if (existingMessage) {
        await existingMessage.update(messageValues)
        const thread = await existingMessage.getThread();
        if (thread) {
          await thread.updateLabelsAndFolders();
        }
        this._logger.info({
          message_id: existingMessage.id,
          uid: existingMessage.folderImapUID,
        }, `FetchMessagesInFolder: Updated message`)
      } else {
        // TODO investigate batching processing new messages
        // We could measure load of actual sync vs load of just message processing
        // to determine how meaningful it is
        processNewMessage(messageValues, imapMessage)
        this._logger.info({
          message: messageValues,
        }, `FetchMessagesInFolder: Queued new message for processing`)
      }
    } catch (err) {
      this._logger.error(err, {
        imapMessage,
        desiredParts,
      }, `FetchMessagesInFolder: Could not build message`)
      const outJSON = JSON.stringify({'imapMessage': imapMessage, 'desiredParts': desiredParts, 'result': {}});
      const outDir = path.join(os.tmpdir(), "k2-parse-errors", this._folder.name)
      const outFile = path.join(outDir, imapMessage.attributes.uid.toString());
      mkdirp.sync(outDir);
      fs.writeFileSync(outFile, outJSON);
    }
  }

  async _openMailboxAndEnsureValidity() {
    const box = await this._imap.openBox(this._folder.name);

    if (box.persistentUIDs === false) {
      throw new Error("Mailbox does not support persistentUIDs.");
    }

    const lastUIDValidity = this._folder.syncState.uidvalidity;

    if (lastUIDValidity && (box.uidvalidity !== lastUIDValidity)) {
      this._logger.info({
        boxname: box.name,
        categoryname: this._folder.name,
        remoteuidvalidity: box.uidvalidity,
        localuidvalidity: lastUIDValidity,
      }, `FetchMessagesInFolder: Recovering from UIDInvalidity`);
      await this._recoverFromUIDInvalidity()
    }

    return box;
  }

  async _fetchUnsyncedMessages() {
    const savedSyncState = this._folder.syncState;
    const isFirstSync = savedSyncState.fetchedmax === undefined;
    const boxUidnext = this._box.uidnext;
    const boxUidvalidity = this._box.uidvalidity;

    const desiredRanges = [];

    this._logger.info({
      range: `${savedSyncState.fetchedmin}:${savedSyncState.fetchedmax}`,
    }, `FetchMessagesInFolder: Fetching messages.`)

    // Todo: In the future, this is where logic should go that limits
    // sync based on number of messages / age of messages.

    if (isFirstSync) {
      const lowerbound = Math.max(1, boxUidnext - FETCH_MESSAGES_FIRST_COUNT);
      desiredRanges.push({min: lowerbound, max: boxUidnext})
    } else {
      if (savedSyncState.fetchedmax < boxUidnext) {
        desiredRanges.push({min: savedSyncState.fetchedmax, max: boxUidnext})
      } else {
        this._logger.info('FetchMessagesInFolder: fetchedmax == uidnext, nothing more recent to fetch.')
      }

      if (savedSyncState.fetchedmin > 1) {
        const lowerbound = Math.max(1, savedSyncState.fetchedmin - FETCH_MESSAGES_COUNT);
        desiredRanges.push({min: lowerbound, max: savedSyncState.fetchedmin})
      } else {
        this._logger.info("FetchMessagesInFolder: fetchedmin == 1, nothing older to fetch.")
      }
    }

    await PromiseUtils.each(desiredRanges, async ({min, max}) => {
      this._logger.info({
        range: `${min}:${max}`,
      }, `FetchMessagesInFolder: Fetching range`);

      await this._fetchMessagesAndQueueForProcessing(`${min}:${max}`);
      const {fetchedmin, fetchedmax} = this._folder.syncState;
      return this.updateFolderSyncState({
        fetchedmin: fetchedmin ? Math.min(fetchedmin, min) : min,
        fetchedmax: fetchedmax ? Math.max(fetchedmax, max) : max,
        uidnext: boxUidnext,
        uidvalidity: boxUidvalidity,
        timeFetchedUnseen: Date.now(),
      });
    });

    this._logger.info(`FetchMessagesInFolder: Fetching messages finished`);
  }

  _runScan() {
    const {fetchedmin, fetchedmax} = this._folder.syncState;
    if ((fetchedmin === undefined) || (fetchedmax === undefined)) {
      throw new Error("Unseen messages must be fetched at least once before the first update/delete scan.")
    }
    return this._shouldRunDeepScan() ? this._runDeepScan() : this._runShallowScan()
  }

  _shouldRunDeepScan() {
    const {timeDeepScan} = this._folder.syncState;
    return Date.now() - (timeDeepScan || 0) > this._options.deepFolderScan;
  }

  async _runShallowScan() {
    const {highestmodseq} = this._folder.syncState;
    const nextHighestmodseq = this._box.highestmodseq;

    let shallowFetch = null;

    if (this._imap.serverSupports(Capabilities.Condstore)) {
      this._logger.info(`FetchMessagesInFolder: Shallow attribute scan (using CONDSTORE)`)
      if (nextHighestmodseq === highestmodseq) {
        this._logger.info('FetchMessagesInFolder: highestmodseq matches, nothing more to fetch')
        return Promise.resolve();
      }
      shallowFetch = this._box.fetchUIDAttributes(`1:*`, {changedsince: highestmodseq});
    } else {
      const range = `${this._getLowerBoundUID(SHALLOW_SCAN_UID_COUNT)}:*`;
      this._logger.info({range}, `FetchMessagesInFolder: Shallow attribute scan`)
      shallowFetch = this._box.fetchUIDAttributes(range);
    }

    const remoteUIDAttributes = await shallowFetch;
    const localMessageAttributes = await this._db.Message.findAll({
      where: {folderId: this._folder.id},
      attributes: MessageFlagAttributes,
    })

    await this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes)

    this._logger.info(`FetchMessagesInFolder: finished fetching changes to messages`);
    return this.updateFolderSyncState({
      highestmodseq: nextHighestmodseq,
      timeShallowScan: Date.now(),
    });
  }

  async _runDeepScan() {
    const {Message} = this._db;
    const {fetchedmin, fetchedmax} = this._folder.syncState;
    const range = `${fetchedmin}:${fetchedmax}`;

    this._logger.info({range}, `FetchMessagesInFolder: Deep attribute scan: fetching attributes in range`)

    const remoteUIDAttributes = await this._box.fetchUIDAttributes(range)
    const localMessageAttributes = await Message.findAll({
      where: {folderId: this._folder.id},
      attributes: MessageFlagAttributes,
    })

    await PromiseUtils.props({
      updates: this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes),
      deletes: this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes),
    })

    this._logger.info(`FetchMessagesInFolder: Deep scan finished.`);

    return this.updateFolderSyncState({
      highestmodseq: this._box.highestmodseq,
      timeDeepScan: Date.now(),
      timeShallowScan: Date.now(),
    });
  }

  async updateFolderSyncState(newState) {
    if (_.isMatch(this._folder.syncState, newState)) {
      return Promise.resolve();
    }
    this._folder.syncState = Object.assign(this._folder.syncState, newState);
    return this._folder.save();
  }

  async run(db, imap) {
    this._db = db;
    this._imap = imap;

    this._box = await this._openMailboxAndEnsureValidity();
    await this._fetchUnsyncedMessages()
    await this._runScan()
  }
}

module.exports = FetchMessagesInFolder;
