const _ = require('underscore');
const {IMAPConnection} = require('isomorphic-core');
const {Capabilities} = IMAPConnection;
const SyncTask = require('./sync-task')
const MessageProcessor = require('../../message-processor')
const {reportSyncActivity} = require('../../shared/sync-activity').default

const MessageFlagAttributes = ['id', 'threadId', 'folderImapUID', 'unread', 'starred', 'folderImapXGMLabels']
const FETCH_ATTRIBUTES_BATCH_SIZE = 1000;
const FETCH_MESSAGE_BATCH_SIZE = 30;
const MIN_MESSAGE_BATCH_SIZE = 30;
const MAX_MESSAGE_BATCH_SIZE = 300;
const BATCH_SIZE_PER_SELECT_SEC = 60;
const GMAIL_INBOX_PRIORITIZE_COUNT = 1000;


class FetchMessagesInFolderIMAP extends SyncTask {
  constructor({account, folder, uids} = {}) {
    super({account})
    this._imap = null
    this._box = null
    this._db = null
    this._folder = folder;
    this._uids = uids;
    if (!this._folder) {
      throw new Error("FetchMessagesInFolderIMAP requires a category")
    }
  }

  description() {
    return `FetchMessagesInFolderIMAP (${this._folder.name} - ${this._folder.id})`;
  }

  _isFirstSync() {
    return this._folder.syncState.minUID == null;
  }

  async _recoverFromUIDInvalidity(boxUidvalidity) {
    // UID invalidity means the server has asked us to delete all the UIDs for
    // this folder and start from scratch. Instead of deleting all the messages,
    // we just remove the folder ID and UID. We may re-assign the same message
    // the same UID. Otherwise they're eventually garbage collected.
    const {Message} = this._db;
    await Message.update({
      folderId: null,
      folderImapUID: null,
    }, {where: {folderId: this._folder.id}})

    await this._folder.updateSyncState({
      fetchedmax: null,
      fetchedmin: null,
      minUID: null,
      uidvalidity: boxUidvalidity,
    });
  }

  async _updateMessageAttributes(remoteUIDAttributes, localMessageAttributes) {
    const {Label, Thread} = this._db;

    const messageAttributesMap = {};
    for (const msg of localMessageAttributes) {
      messageAttributesMap[msg.folderImapUID] = msg;
    }

    const messagesWithChangedFlags = [];
    const messagesWithChangedLabels = [];

    // Step 1: Identify changed messages and update their attributes in place

    const preloadedLabels = await Label.findAll();
    for (const uid of Object.keys(remoteUIDAttributes)) {
      const msg = messageAttributesMap[uid];
      const attrs = remoteUIDAttributes[uid];

      if (!msg) continue;

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
    }

    // Step 2: If flags were changed, apply the changes to the corresponding
    // threads. We do this as a separate step so we can batch-load the threads.
    if (messagesWithChangedFlags.length > 0) {
      const threadIds = messagesWithChangedFlags.map(m => m.threadId);
      const threads = await Thread.findAll({
        attributes: ['id', 'unreadCount', 'starredCount'],
        where: {id: threadIds},
      });
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
      for (const thread of threads) {
        await thread.save({fields: ['starredCount', 'unreadCount']})
      }
    }

    // Step 3: Persist the messages we've updated
    const messagesChanged = [].concat(messagesWithChangedFlags, messagesWithChangedLabels);
    for (const messageChanged of messagesChanged) {
      await messageChanged.save({fields: MessageFlagAttributes})
    }

    // Step 4: If message labels were changed, retrieve the impacted threads
    // and re-compute their labels. This is fairly expensive at the moment.
    if (messagesWithChangedLabels.length > 0) {
      const threadIds = messagesWithChangedLabels.map(m => m.threadId);
      const threads = await Thread.findAll({
        attributes: ['id'],
        where: {id: threadIds},
      });
      for (const thread of threads) {
        await thread.updateLabelsAndFolders()
      }
    }
    return {
      numChangedLabels: messagesWithChangedLabels.length,
      numChangedFlags: messagesWithChangedFlags.length,
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

    await Message.update({
      folderImapUID: null,
      folderId: null,
    }, {where: {folderId: this._folder.id, folderImapUID: removedUIDs}})
  }

  _getDesiredMIMEParts(struct) {
    const desired = [];
    const available = [];
    const unseen = [struct];
    const desiredTypes = new Set(['text/plain', 'text/html']);
    // MIME structures can be REALLY FREAKING COMPLICATED. To simplify
    // processing, we flatten the MIME structure by walking it depth-first,
    // throwing away all multipart headers with the exception of
    // multipart/alternative trees. We special case these, flattening via a
    // recursive call and then extracting only HTML parts, since their
    // equivalent nature allows us to pick our desired representation and throw
    // away the rest.
    while (unseen.length > 0) {
      const part = unseen.shift();
      if (part instanceof Array && (part[0].type !== 'alternative')) {
        unseen.unshift(...part);
      } else if (part instanceof Array && (part[0].type === 'alternative')) {
        // Picking our desired alternative part(s) here vastly simplifies
        // later parsing of the body, since we can then completely ignore
        // mime structure without making any terrible mistakes. We assume
        // here that all multipart/alternative MIME parts are arrays of
        // text/plain vs text/html, which is ~always true (and if it isn't,
        // the message is bound to be absurd in other ways and we can't
        // guarantee sensible display).
        part.shift();
        const htmlParts = this._getDesiredMIMEParts(part).filter((p) => {
          return p.mimeType === 'text/html';
        });
        if (htmlParts.length > 0) {
          // Some bizarre emails contain multiple copies of the same MIME
          // part with the same MIME type. Since multipart/alternative
          // indicates that each MIME part is a representation of equivalent
          // data, we can safely keep only one.
          desired.push(htmlParts[0]);
        }
      } else {
        if (part.size) { // will skip all multipart types
          const mimeType = `${part.type}/${part.subtype}`;
          available.push(mimeType);
          const disposition = part.disposition ? part.disposition.type.toLowerCase() : null;
          if (desiredTypes.has(mimeType) && (disposition !== 'attachment')) {
            desired.push({
              id: part.partID,
              // encoding and charset may be null
              transferEncoding: part.encoding,
              charset: part.params ? part.params.charset : null,
              mimeType,
            });
          }
        }
      }
      // attachment metadata is extracted later---ignore for now
    }

    if (desired.length === 0 && available.length !== 0) {
      this._logger.warn(`FetchMessagesInFolderIMAP: Could not find good part`, {
        available_options: available.join(', '),
      })
    }

    return desired;
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   *
   * This either fetches a range from `min` to `maxA`
   * OR
   * It can fetch a specific set of `uids`
   */
  async * _fetchAndProcessMessages({min, max, uids, throttle = true} = {}) {
    let rangeQuery;
    if (uids) {
      if (min || max) {
        throw new Error(`Cannot pass min/max AND uid set`);
      }
      rangeQuery = uids;
    } else {
      if (min < 0 || max < 0) {
        throw new Error(`Min (${min}) and max (${max}) must be > 0`);
      } // it's OK if max < min though, IMAP will just invert them
      rangeQuery = `${min}:${max}`;
    }

    // this._logger.log(`FetchMessagesInFolderIMAP: Going to FETCH messages in range ${rangeQuery}`);
    if (!this._syncWorker._batchProcessedUids.has(this._folder.name)) {
      this._syncWorker._batchProcessedUids.set(this._folder.name, new Set())
    }
    const processedUids = this._syncWorker._batchProcessedUids.get(this._folder.name);

    // We batch downloads by which MIME parts from the full message we want
    // because we can fetch the same part on different UIDs with the same
    // FETCH, thus minimizing round trips.
    const uidsByPart = {};
    const structsByUID = {};
    const desiredPartsByUID = {};
    yield this._box.fetchEach(rangeQuery, {struct: true}, ({attributes}) => {
      if (!processedUids.has(attributes.uid)) {
        const desiredParts = this._getDesiredMIMEParts(attributes.struct);
        const key = JSON.stringify(desiredParts.map(p => p.id));
        desiredPartsByUID[attributes.uid] = desiredParts;
        structsByUID[attributes.uid] = attributes.struct;
        uidsByPart[key] = uidsByPart[key] || [];
        uidsByPart[key].push(attributes.uid);
      }
    })

    // Prioritize the batches with the highest UIDs first, since these UIDs
    // are usually the most recent messages
    const maxUIDForBatch = {};
    const partBatchesInOrder = Object.keys(uidsByPart)
    for (const key of partBatchesInOrder) {
      maxUIDForBatch[key] = Math.max(...uidsByPart[key]);
    }
    partBatchesInOrder.sort((a, b) => maxUIDForBatch[b] - maxUIDForBatch[a]);

    let totalProcessedMessages = 0
    for (const key of partBatchesInOrder) {
      const desiredPartIDs = JSON.parse(key);
      // headers are BIG (something like 30% of total storage for an average
      // mailbox), so only download the ones we care about
      const bodies = ['HEADER.FIELDS (FROM TO SUBJECT DATE CC BCC REPLY-TO IN-REPLY-TO REFERENCES MESSAGE-ID)'].concat(desiredPartIDs);

      const messagesToProcess = []
      yield this._box.fetchEach(
        uidsByPart[key],
        {bodies},
        (imapMessage) => messagesToProcess.push(imapMessage)
      );
      // generally higher UIDs are newer, so process those first
      messagesToProcess.sort((a, b) => b.attributes.uid - a.attributes.uid);

      // Processing messages is not fire and forget.
      // We need to wait for all of the messages in the range to be processed
      // before actually updating the folder sync state. If we optimistically
      // updated the fetched range, we would have to persist the processing
      // queue to disk in case you quit the app and there are still messages
      // left in the queue. Otherwise we would end up skipping messages.
      for (const imapMessage of messagesToProcess) {
        const uid = imapMessage.attributes.uid;
        // This will resolve when the message is actually processed
        await MessageProcessor.queueMessageForProcessing({
          imapMessage,
          struct: structsByUID[uid],
          desiredParts: desiredPartsByUID[uid],
          folderId: this._folder.id,
          accountId: this._db.accountId,
          throttle,
        })
        processedUids.add(uid);
        this.emit('message-processed');

        // If the user quits the app at this point, we will have to refetch
        // these messages because the folder.syncState won't get updated, but
        // that's ok.
        yield // Yield to allow interruption
      }
      totalProcessedMessages += messagesToProcess.length;
    }

    // `uids` set is used for prioritizing specific uids. We can't update the
    // range if this is passed because we still want to download the rest of
    // the range later.
    if (!uids) {
      // Update our folder sync state to reflect the messages we've synced
      const boxUidnext = this._box.uidnext;
      const boxUidvalidity = this._box.uidvalidity;
      const {fetchedmin, fetchedmax} = this._folder.syncState;
      await this._folder.updateSyncState({
        fetchedmin: fetchedmin ? Math.min(fetchedmin, min) : min,
        fetchedmax: fetchedmax ? Math.max(fetchedmax, max) : max,
        uidnext: boxUidnext,
        uidvalidity: boxUidvalidity,
      });
      // to keep processedUids from growing without bound, expunge UIDs for
      // ranges which have been recorded as fully downloaded
      for (const uid of processedUids.values()) {
        if (uid >= Math.min(min, max) && uid <= Math.max(min, max)) {
          processedUids.delete(uid)
        }
      }
    }

    return totalProcessedMessages
  }

  _batchSizeForFolder() {
    if (!this._syncWorker._latestOpenTimesByFolder.has(this._folder.name)) {
      this._logger.log(`Unknown folder ${this._folder.name}, returning batch size of ${MIN_MESSAGE_BATCH_SIZE}`);
      return MIN_MESSAGE_BATCH_SIZE;
    }
    const selectTimeSec = this._syncWorker._latestOpenTimesByFolder.get(this._folder.name) / 1000.0;
    const batchSize = Math.floor(Math.min(Math.max(selectTimeSec * BATCH_SIZE_PER_SELECT_SEC, MIN_MESSAGE_BATCH_SIZE), MAX_MESSAGE_BATCH_SIZE));
    this._logger.log(`Selecting folder ${this._folder.name} previously took ${selectTimeSec} seconds, returning batch size of ${batchSize}`);
    return batchSize;
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _openMailboxAndEnsureValidity() {
    const box = await this._imap.openBox(this._folder.name, {refetchBoxInfo: true});
    this._syncWorker._latestOpenTimesByFolder.set(this._folder.name, this._imap.getLastOpenDuration());
    yield

    if (box.persistentUIDs === false) {
      throw new Error("Mailbox does not support persistentUIDs.");
    }

    const boxUidvalidity = box.uidvalidity;
    const lastUIDValidity = this._folder.syncState.uidvalidity;

    if (lastUIDValidity && (boxUidvalidity !== lastUIDValidity)) {
      this._logger.log(`🔃  😵  📂 ${this._folder.name} - Recovering from UID invalidity`)
      await this._recoverFromUIDInvalidity(boxUidvalidity)
    }

    return box;
  }

  async * _fetchFirstUnsyncedMessages(batchSize) {
    const {provider} = this._account;
    const folderRole = this._folder.role;
    const gmailInboxUIDsRemaining = this._folder.syncState.gmailInboxUIDsRemaining;
    const gmailInboxUIDsUnset = !gmailInboxUIDsRemaining;
    const hasGmailInboxUIDsRemaining = gmailInboxUIDsRemaining && gmailInboxUIDsRemaining.length
    let totalProcessedMessages = 0;
    if (provider === "gmail" && folderRole === "all" && (gmailInboxUIDsUnset || hasGmailInboxUIDsRemaining)) {
      // Track the first few UIDs in the inbox label & download these first.
      // If the user restarts the app before all these UIDs are downloaded & we
      // also pass the UID in the All Mail folder range downloads we will
      // redownload them, but that's OK.
      let inboxUids;
      if (!gmailInboxUIDsRemaining) {
        // this._logger.log(`FetchMessagesInFolderIMAP: Fetching Gmail Inbox UIDs for prioritization`);
        inboxUids = await this._box.search([['X-GM-RAW', 'in:inbox']]);
        // Gmail always returns UIDs in order from smallest to largest, so this
        // gets us the most recent messages first.
        inboxUids = inboxUids.slice(Math.max(inboxUids.length - GMAIL_INBOX_PRIORITIZE_COUNT, 0));
        // Immediately persist to avoid issuing search again in case of interrupt
        await this._folder.updateSyncState({
          gmailInboxUIDsRemaining: inboxUids,
          fetchedmax: this._box.uidnext,
        });
      } else {
        inboxUids = this._folder.syncState.gmailInboxUIDsRemaining;
      }
      // continue fetching new mail first in the case that inbox uid download
      // takes multiple batches
      const fetchedmax = this._folder.syncState.fetchedmax || this._box.uidnext;
      if (this._box.uidnext > fetchedmax) {
        this._logger.log(`🔃 📂 ${this._folder.name} new messages present; fetching ${fetchedmax}:${this._box.uidnext}`);
        totalProcessedMessages += yield this._fetchAndProcessMessages({min: fetchedmax, max: this._box.uidnext, throttle: false});
      }
      const batchSplitIndex = Math.max(inboxUids.length - batchSize, 0);
      const uidsFetchNow = inboxUids.slice(batchSplitIndex);
      const uidsFetchLater = inboxUids.slice(0, batchSplitIndex);
      // this._logger.log(`FetchMessagesInFolderIMAP: Remaining Gmail Inbox UIDs to download: ${uidsFetchLater.length}`);
      totalProcessedMessages += yield this._fetchAndProcessMessages({uids: uidsFetchNow, throttle: false});
      await this._folder.updateSyncState({ gmailInboxUIDsRemaining: uidsFetchLater });
    } else {
      const lowerbound = Math.max(1, this._box.uidnext - batchSize);
      totalProcessedMessages += yield this._fetchAndProcessMessages({min: lowerbound, max: this._box.uidnext, throttle: false});
      // We issue a UID FETCH ALL and record the correct minimum UID for the
      // mailbox, which could be something much larger than 1 (especially for
      // inbox because of archiving, which "loses" smaller UIDs over time). If
      // we do not do this, and, say, the minimum UID in a mailbox is 100k
      // (we've seen this!), the mailbox will not register as finished initial
      // syncing for many many sync loop iterations beyond when it is actually
      // complete, and we will issue many unnecessary FETCH commands.
      //
      // We do this _after_ fetching the first few messages in the mailbox in
      // order to prioritize the time to first thread displayed on initial
      // account connection.
      const uids = await this._box.search([['UID', `1:${lowerbound}`]]);
      let boxMinUid = uids[0] || 1;
      // Using old-school min because uids may be an array of a million
      // items. Math.min can't take that many arguments
      for (const uid of uids) {
        if (uid < boxMinUid) {
          boxMinUid = uid;
        }
      }
      await this._folder.updateSyncState({ minUID: boxMinUid });
    }

    return totalProcessedMessages
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _fetchUnsyncedMessages(batchSize) {
    const savedSyncState = this._folder.syncState;
    const boxUidnext = this._box.uidnext;

    if (!savedSyncState.minUID) {
      throw new Error("minUID is not set. You must restart the sync loop or check boxMinUid")
    }

    let totalProcessedMessages = 0
    if (savedSyncState.fetchedmax < boxUidnext) {
      // this._logger.log(`FetchMessagesInFolderIMAP: fetching ${savedSyncState.fetchedmax}:${boxUidnext}`);
      totalProcessedMessages += yield this._fetchAndProcessMessages({min: savedSyncState.fetchedmax, max: boxUidnext, throttle: false});
    } else {
      // this._logger.log('FetchMessagesInFolderIMAP: fetchedmax == uidnext, nothing more recent to fetch.')
    }

    if (savedSyncState.fetchedmin > savedSyncState.minUID) {
      const lowerbound = Math.max(savedSyncState.minUID, savedSyncState.fetchedmin - batchSize);
      // this._logger.log(`FetchMessagesInFolderIMAP: fetching ${lowerbound}:${savedSyncState.fetchedmin}`);
      totalProcessedMessages += yield this._fetchAndProcessMessages({min: lowerbound, max: savedSyncState.fetchedmin});
    } else {
      // this._logger.log("FetchMessagesInFolderIMAP: fetchedmin == minUID, nothing older to fetch.")
    }
    return totalProcessedMessages
  }

  async * _fetchNextMessageBatch() {
    // Since we expand the UID FETCH range without comparing to the UID list
    // because UID SEARCH ALL can be slow (and big!), we may download fewer
    // messages than the batch size (up to zero) --- keep going until full
    // batch synced
    let totalProcessedMessages = 0;
    const moreToFetchAvailable = () => !this._folder.isSyncComplete() || this._box.uidnext > this._folder.syncState.fetchedmax
    const batchSize = this._batchSizeForFolder(this._folder);
    while (totalProcessedMessages < batchSize && moreToFetchAvailable()) {
      if (this._isFirstSync()) {
        const numProcessed = yield this._fetchFirstUnsyncedMessages(batchSize);
        totalProcessedMessages += numProcessed;
        continue;
      }

      const numProcessed = yield this._fetchUnsyncedMessages(batchSize);
      totalProcessedMessages += numProcessed
      if (numProcessed > 0) {
        continue;
      }

      // Find where the gap in the UID space ends --- SEARCH can be slow on
      // large mailboxes, but otherwise we could spin here arbitrarily long
      // FETCHing empty space
      let nextUid = 1;
      // IMAP range searches include both ends of the range
      const minSearchUid = this._folder.syncState.fetchedmin - 1;
      if (minSearchUid) {
        const uids = await this._box.search([['UID', `${this._folder.syncState.minUID}:${minSearchUid}`]]);
        // Using old-school max because uids may be an array of a million
        // items. Math.max can't take that many arguments
        nextUid = uids[0] || 1;
        for (const uid of uids) {
          if (uid > nextUid) {
            nextUid = uid;
          }
        }
      }
      this._logger.log(`🔃📂 ${this._folder.name} Found gap in UIDs; next fetchedmin is ${nextUid}`);
      await this._folder.updateSyncState({ fetchedmin: nextUid });
    }
  }

  /**
   * We need to periodically check if any attributes have changed on
   * messages. These are things like "starred" or "unread", etc. There are
   * two types of IMAP boxes: one that supports "highestmodseq" via the
   * "CONDSTORE" flag, and ones that do not. In the former case we can
   * basically ask for the latest messages that have changes. In the
   * latter case we have to slowly traverse through all messages in order
   * to find updates.
   *
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  * _fetchMessageAttributeChanges() {
    const {fetchedmin, fetchedmax} = this._folder.syncState;
    if ((fetchedmin === undefined) || (fetchedmax === undefined)) {
      throw new Error("Unseen messages must be fetched at least once before the first update/delete scan.")
    }

    if (this._supportsChangesSince()) {
      yield this._fetchLatestAttributeChanges()
    } else {
      yield this._scanForAttributeChanges();
    }
  }

  /**
   * Some IMAP providers have "CONDSTORE" as a capibility. This allows us
   * to ask for any messages that have had their attributes changed since
   * a certain timestamp. This is a much nicer feature than slowly looking
   * back through all messages for ones that have updated attributes.
   */
  _supportsChangesSince() {
    return this._imap.serverSupports(Capabilities.Condstore)
  }

  /**
   * For providers that have CONDSTORE enabled, we can use the
   * `highestmodseq` and `changedsince` parameters to ask for messages
   * that have had their attributes updated since a recent timestamp. We
   * used to refer to this as a "shallowScan".
   *
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _fetchLatestAttributeChanges() {
    const {highestmodseq} = this._folder.syncState;
    const nextHighestmodseq = this._box.highestmodseq;
    if (!highestmodseq || nextHighestmodseq === highestmodseq) {
      await this._folder.updateSyncState({
        highestmodseq: nextHighestmodseq,
      });
      return;
    }

    const start = Date.now()
    this._logger.log(`🔃 🚩 ${this._folder.name} via highestmodseq of ${highestmodseq}`)

    const remoteUIDAttributes = yield this._box.fetchUIDAttributes(`1:*`,
      {modifiers: {changedsince: highestmodseq}});
    const localMessageAttributes = yield this._db.Message.findAll({
      where: {
        folderId: this._folder.id,
        folderImapUID: _.compact(Object.keys(remoteUIDAttributes)),
      },
      attributes: MessageFlagAttributes,
    })

    const {numChangedLabels, numChangedFlags} = await this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes)
    await this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes)
    await this._folder.updateSyncState({
      highestmodseq: nextHighestmodseq,
    });
    this._logger.log(`🔃 🚩 ${this._folder.name} via highestmodseq of ${highestmodseq} - took ${Date.now() - start}ms to update ${numChangedLabels + numChangedFlags} messages & threads`)
  }

  /**
   * For providers that do NOT have CONDSTORE enabled, we have to slowly
   * go back through all messages to find if any attributes have changed.
   * Since there may be millions of messages, we need to break this up
   * into reasonable chunks to do it efficiently.
   *
   * We always scan the most recent FETCH_ATTRIBUTE_BATCH_SIZE messages
   * since we assume those are the most likely to have their attributes
   * updated.
   *
   * After we slowly scan backwards by the batch size over the rest of the
   * mailbox over the next several syncs.
   *
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _scanForAttributeChanges() {
    const {Message} = this._db;
    const {fetchedmax, attributeFetchedMax} = this._folder.syncState;

    const recentStart = Math.max(fetchedmax - FETCH_ATTRIBUTES_BATCH_SIZE, 1)
    const recentRange = `${recentStart}:${fetchedmax}`;

    const to = Math.min(attributeFetchedMax || recentStart, recentStart);
    const from = Math.max(to - FETCH_ATTRIBUTES_BATCH_SIZE, 1)
    const backScanRange = `${from}:${to}`;

    const start = Date.now()
    this._logger.log(`🔃 🚩 ${this._folder.name} via scan through ${recentRange} and ${backScanRange}`)

    const recentAttrs = yield this._box.fetchUIDAttributes(recentRange)
    const backScanAttrs = yield this._box.fetchUIDAttributes(backScanRange)
    const remoteUIDAttributes = Object.assign({}, backScanAttrs, recentAttrs)
    const localMessageAttributes = yield Message.findAll({
      where: {
        folderId: this._folder.id,
        folderImapUID: _.compact(Object.keys(remoteUIDAttributes)),
      },
      attributes: MessageFlagAttributes,
    })

    const {numChangedLabels, numChangedFlags} = await this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes)
    await this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes)

    // this._logger.info(`FetchMessagesInFolder: Deep scan finished.`);
    await this._folder.updateSyncState({
      attributeFetchedMax: (from <= 1 ? recentStart : from),
      lastAttributeScanTime: Date.now(),
    });
    this._logger.log(`🔃 🚩 ${this._folder.name} via scan through ${recentRange} and ${backScanRange} - took ${Date.now() - start}ms to update ${numChangedLabels + numChangedFlags} messages & threads`)
  }

  _shouldFetchMessages(boxStatus) {
    if (boxStatus.name !== this._folder.name) {
      throw new Error(`FetchMessagesInFolder::_shouldFetchMessages - boxStatus doesn't correspond to folder`)
    }
    if (!this._folder.isSyncComplete()) {
      return true
    }
    const {syncState: {fetchedmax, uidvalidity}} = this._folder
    return boxStatus.uidvalidity !== uidvalidity || boxStatus.uidnext > fetchedmax
  }

  _shouldFetchAttributes(boxStatus) {
    if (boxStatus.name !== this._folder.name) {
      throw new Error(`FetchMessagesInFolder::_shouldFetchAttributes - boxStatus doesn't correspond to folder`)
    }
    if (!this._folder.isSyncComplete()) {
      return true
    }
    const {syncState} = this._folder
    if (this._supportsChangesSince()) {
      return syncState.highestmodseq !== boxStatus.highestmodseq
    }
    return true
  }

  _shouldSyncFolder(boxStatus) {
    return this._shouldFetchMessages(boxStatus) || this._shouldFetchAttributes(boxStatus)
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * runTask(db, imap, syncWorker) {
    const accountId = this._db.accountId
    const folderName = this._folder.name
    reportSyncActivity(accountId, `Starting folder: ${folderName}`)
    this._logger.log(`🔜 📂 ${this._folder.name}`)
    this._db = db;
    this._imap = imap;
    if (!syncWorker) {
      throw new Error(`SyncWorker not passed to runTask`);
    }
    this._syncWorker = syncWorker;

    const latestBoxStatus = yield this._imap.getLatestBoxStatus(this._folder.name)

    // If we haven't set any syncState at all, let's set it for the first time
    // to generate a delta for N1
    if (_.isEmpty(this._folder.syncState)) {
      yield this._folder.updateSyncState({
        uidnext: latestBoxStatus.uidnext,
        uidvalidity: latestBoxStatus.uidvalidity,
        fetchedmin: null,
        fetchedmax: null,
        minUID: null,
        failedUIDs: [],
      })
    }

    reportSyncActivity(accountId, `Checking if folder needs sync: ${folderName}`)

    if (!this._shouldSyncFolder(latestBoxStatus)) {
      // Don't even attempt to issue an IMAP SELECT if there are absolutely no
      // updates
      this._logger.log(`🔚 📂 ${this._folder.name} has no updates at all - skipping sync`)
      reportSyncActivity(accountId, `Done with folder: ${folderName}`)
      return;
    }

    reportSyncActivity(accountId, `Checking what to fetch for folder: ${folderName}`)

    this._box = yield this._openMailboxAndEnsureValidity();
    const shouldFetchMessages = this._shouldFetchMessages(this._box)
    const shouldFetchAttributes = this._shouldFetchAttributes(this._box)

    // Do as little work as possible
    if (shouldFetchMessages) {
      reportSyncActivity(accountId, `Fetching messages: ${folderName}`)
      yield this._fetchNextMessageBatch()
    } else {
      this._logger.log(`🔚 📂 ${this._folder.name} has no new messages - skipping fetch messages`)
    }
    if (shouldFetchAttributes) {
      reportSyncActivity(accountId, `Fetching attributes: ${folderName}`)
      yield this._fetchMessageAttributeChanges();
    } else {
      this._logger.log(`🔚 📂 ${this._folder.name} has no attribute changes - skipping fetch attributes`)
    }
    this._logger.log(`🔚 📂 ${this._folder.name} done`)
    reportSyncActivity(accountId, `Done with folder: ${folderName}`)
  }
}

module.exports = FetchMessagesInFolderIMAP;
