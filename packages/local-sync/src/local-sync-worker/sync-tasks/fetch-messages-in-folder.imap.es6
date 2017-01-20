const _ = require('underscore');
const {IMAPConnection} = require('isomorphic-core');
const {Capabilities} = IMAPConnection;
const SyncTask = require('./sync-task')
const MessageProcessor = require('../../message-processor')

const MessageFlagAttributes = ['id', 'threadId', 'folderImapUID', 'unread', 'starred', 'folderImapXGMLabels']
const FETCH_ATTRIBUTES_BATCH_SIZE = 1000;
const FETCH_MESSAGES_COUNT = 30;
const GMAIL_INBOX_PRIORITIZE_COUNT = 1000;


class FetchMessagesInFolderIMAP extends SyncTask {
  constructor({account, folder} = {}) {
    super({account})
    this._imap = null
    this._box = null
    this._db = null
    this._folder = folder;
    this._fetchedMsgCount = 0;
    if (!this._folder) {
      throw new Error("FetchMessagesInFolderIMAP requires a category")
    }
  }

  description() {
    return `FetchMessagesInFolderIMAP (${this._folder.name} - ${this._folder.id})`;
  }

  _isFirstSync() {
    return this._folder.syncState.minUID == null || this._folder.syncState.fetchedmax == null;
  }

  async _recoverFromUIDInvalidity() {
    // UID invalidity means the server has asked us to delete all the UIDs for
    // this folder and start from scratch. Instead of deleting all the messages,
    // we just remove the category ID and UID. We may re-assign the same message
    // the same UID. Otherwise they're eventually garbage collected.
    const {Message} = this._db;
    await Message.update({
      folderImapUID: null,
      folderId: null,
    }, {where: {folderId: this._folder.id}})
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
          desired.push(...htmlParts);
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
      console.warn(`FetchMessagesInFolderIMAP: Could not find good part`, {
        available_options: available.join(', '),
      })
    }

    return desired;
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _fetchAndProcessMessages({min, max, uids} = {}) {
    const uidsByPart = {};
    const structsByPart = {};
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

    // console.log(`FetchMessagesInFolderIMAP: Going to FETCH messages in range ${rangeQuery}`);

    yield this._box.fetchEach(rangeQuery, {struct: true}, ({attributes}) => {
      const desiredParts = this._getDesiredMIMEParts(attributes.struct);
      const key = JSON.stringify(desiredParts);
      uidsByPart[key] = uidsByPart[key] || [];
      uidsByPart[key].push(attributes.uid);
      structsByPart[key] = attributes.struct;
    })

    for (const key of Object.keys(uidsByPart)) {
      // note: the order of UIDs in the array doesn't matter, Gmail always
      // returns them in ascending (oldest => newest) order.
      const desiredParts = JSON.parse(key);
      // headers are BIG (something like 30% of total storage for an average
      // mailbox), so only download the ones we care about
      const bodies = ['HEADER.FIELDS (FROM TO SUBJECT DATE CC BCC REPLY-TO IN-REPLY-TO REFERENCES MESSAGE-ID)'].concat(desiredParts.map(p => p.id));
      const struct = structsByPart[key];

      const messagesToProcess = []
      yield this._box.fetchEach(
        uidsByPart[key],
        {bodies},
        (imapMessage) => messagesToProcess.push(imapMessage)
      );

      // Processing messages is not fire and forget.
      // We need to wait for all of the messages in the range to be processed
      // before actually updating the folder sync state. If we optimistically
      // updated the fetched range, we would have to persist the processing
      // queue to disk in case you quit the app and there are still messages
      // left in the queue. Otherwise we would end up skipping messages.
      for (const imapMessage of messagesToProcess) {
        // This will resolve when the message is actually processed
        await MessageProcessor.queueMessageForProcessing({
          imapMessage,
          struct,
          desiredParts,
          folderId: this._folder.id,
          accountId: this._db.accountId,
        })

        // If execution gets interrupted here, we will have to refetch these
        // messages because the folder.syncState won't get updated, but that's
        // ok.
        yield // Yield to allow interruption
      }
      this._fetchedMsgCount += messagesToProcess.length;
    }

    // `uids` set is used for prioritizing specific uids. We can't update the
    // range if this is passed because we still want to download the rest of
    // the range later.
    if (!uids) {
      // Update our folder sync state to reflect the messages we've synced and
      // processed
      const boxUidnext = this._box.uidnext;
      const boxUidvalidity = this._box.uidvalidity;
      const {fetchedmin, fetchedmax} = this._folder.syncState;
      await this._folder.updateSyncState({
        fetchedmin: fetchedmin ? Math.min(fetchedmin, min) : min,
        fetchedmax: fetchedmax ? Math.max(fetchedmax, max) : max,
        uidnext: boxUidnext,
        uidvalidity: boxUidvalidity,
      });
    }
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _openMailboxAndEnsureValidity() {
    const box = yield this._imap.openBox(this._folder.name, {refetchBoxInfo: true});

    if (box.persistentUIDs === false) {
      throw new Error("Mailbox does not support persistentUIDs.");
    }

    const lastUIDValidity = this._folder.syncState.uidvalidity;

    if (lastUIDValidity && (box.uidvalidity !== lastUIDValidity)) {
      console.log(`🔃  😵  📂 ${this._folder.name} - Recovering from UID invalidity`)
      await this._recoverFromUIDInvalidity()
    }

    return box;
  }

  async * _fetchFirstUnsyncedMessages() {
    const {provider} = this._account;
    const folderRole = this._folder.role;
    const gmailInboxUIDsRemaining = this._folder.syncState.gmailInboxUIDsRemaining;
    const gmailInboxUIDsUnset = !gmailInboxUIDsRemaining;
    const hasGmailInboxUIDsRemaining = gmailInboxUIDsRemaining && gmailInboxUIDsRemaining.length
    if (provider === "gmail" && folderRole === "all" && (gmailInboxUIDsUnset || hasGmailInboxUIDsRemaining)) {
      // Track the first few UIDs in the inbox label & download these first.
      // TODO: this does not prevent us from redownloading all of these
      // UIDs when we finish the first 1k & go back to UID range expansion
      let inboxUids;
      if (!gmailInboxUIDsRemaining) {
        // console.log(`FetchMessagesInFolderIMAP: Fetching Gmail Inbox UIDs for prioritization`);
        inboxUids = await this._box.search([['X-GM-RAW', 'in:inbox']]);
        // Gmail always returns UIDs in order from smallest to largest, so this
        // gets us the most recent messages first.
        inboxUids = inboxUids.slice(Math.max(inboxUids.length - GMAIL_INBOX_PRIORITIZE_COUNT, 0));
      } else {
        inboxUids = this._folder.syncState.gmailInboxUIDsRemaining;
      }
      const batchSplitIndex = Math.max(inboxUids.length - FETCH_MESSAGES_COUNT, 0);
      const uidsFetchNow = inboxUids.slice(batchSplitIndex);
      const uidsFetchLater = inboxUids.slice(0, batchSplitIndex);
      // console.log(`FetchMessagesInFolderIMAP: Remaining Gmail Inbox UIDs to download: ${fetchLater.length}`);
      yield this._fetchAndProcessMessages({uids: uidsFetchNow});
      await this._folder.updateSyncState({ gmailInboxUIDsRemaining: uidsFetchLater });
    } else {
      const lowerbound = Math.max(1, this._box.uidnext - FETCH_MESSAGES_COUNT);
      yield this._fetchAndProcessMessages({min: lowerbound, max: this._box.uidnext});
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
  }

  /**
   * Note: This function is an ES6 generator so we can `yield` at points
   * we want to interrupt sync. This is enabled by `SyncOperation` and
   * `Interruptible`
   */
  async * _fetchUnsyncedMessages() {
    const savedSyncState = this._folder.syncState;
    const boxUidnext = this._box.uidnext;

    // TODO: In the future, this is where logic should go that limits
    // sync based on number of messages / age of messages.

    if (this._isFirstSync()) {
      yield this._fetchFirstUnsyncedMessages();
      return;
    }

    if (!savedSyncState.minUID) {
      throw new Error("minUID is not set. You must restart the sync loop or check boxMinUid")
    }

    if (savedSyncState.fetchedmax < boxUidnext) {
      // console.log(`FetchMessagesInFolderIMAP: fetching ${savedSyncState.fetchedmax}:${boxUidnext}`);
      yield this._fetchAndProcessMessages({min: savedSyncState.fetchedmax, max: boxUidnext});
    } else {
      // console.log('FetchMessagesInFolderIMAP: fetchedmax == uidnext, nothing more recent to fetch.')
    }

    if (savedSyncState.fetchedmin > savedSyncState.minUID) {
      const lowerbound = Math.max(savedSyncState.minUID, savedSyncState.fetchedmin - FETCH_MESSAGES_COUNT);
      // console.log(`FetchMessagesInFolderIMAP: fetching ${lowerbound}:${savedSyncState.fetchedmin}`);
      yield this._fetchAndProcessMessages({min: lowerbound, max: savedSyncState.fetchedmin});
    } else {
      // console.log("FetchMessagesInFolderIMAP: fetchedmin == minUID, nothing older to fetch.")
    }
  }

  async * _fetchNextMessageBatch() {
    // Since we expand the UID FETCH range without comparing to the UID list
    // because UID SEARCH ALL can be slow (and big!), we may download fewer
    // messages than the batch size (up to zero) --- keep going until full
    // batch synced
    const fetchedEnough = () => this._fetchedMsgCount >= FETCH_MESSAGES_COUNT
    const moreToFetchAvailable = () => !this._folder.isSyncComplete() || this._box.uidnext > this._folder.syncState.fetchedmax
    while (!fetchedEnough() && moreToFetchAvailable()) {
      const prevMsgCount = this._fetchedMsgCount;
      yield this._fetchUnsyncedMessages();

      // If we didn't find any messages at all
      if (this._fetchedMsgCount === prevMsgCount) {
        // Find where the gap in the UID space ends --- SEARCH can be slow on
        // large mailboxes, but otherwise we could spin here arbitrarily long
        // FETCHing empty space
        let nextUid;
        // IMAP range searches include both ends of the range
        const minSearchUid = this._folder.syncState.fetchedmin - 1;
        if (minSearchUid) {
          const uids = await this._box.search([['UID',
            `${this._folder.syncState.minUID}:${minSearchUid}`]]);
          // Using old-school max because uids may be an array of a million
          // items. Math.max can't take that many arguments
          nextUid = uids[0] || 1;
          for (const uid of uids) {
            if (uid > nextUid) {
              nextUid = uid;
            }
          }
        } else {
          nextUid = 1;
        }
        console.log(`🔃📂 ${this._folder.name} Found gap in UIDs; next fetchedmin is ${nextUid}`);
        await this._folder.updateSyncState({ fetchedmin: nextUid });
      }
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
    console.log(`🔃 🚩 ${this._folder.name} via highestmodseq of ${highestmodseq}`)

    const remoteUIDAttributes = yield this._box.fetchUIDAttributes(`1:*`,
      {modifiers: {changedsince: highestmodseq}});
    const localMessageAttributes = yield this._db.Message.findAll({
      where: {folderImapUID: _.compact(Object.keys(remoteUIDAttributes))},
      attributes: MessageFlagAttributes,
    })

    const {numChangedLabels, numChangedFlags} = await this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes)
    await this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes)
    await this._folder.updateSyncState({
      highestmodseq: nextHighestmodseq,
    });
    console.log(`🔃 🚩 ${this._folder.name} via highestmodseq of ${highestmodseq} - took ${Date.now() - start}ms to update ${numChangedLabels + numChangedFlags} messages & threads`)
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
    console.log(`🔃 🚩 ${this._folder.name} via scan through ${recentRange} and ${backScanRange}`)

    const recentAttrs = yield this._box.fetchUIDAttributes(recentRange)
    const backScanAttrs = yield this._box.fetchUIDAttributes(backScanRange)
    const remoteUIDAttributes = Object.assign({}, backScanAttrs, recentAttrs)
    const localMessageAttributes = yield Message.findAll({
      where: {folderImapUID: _.compact(Object.keys(remoteUIDAttributes))},
      attributes: MessageFlagAttributes,
    })

    const {numChangedLabels, numChangedFlags} = await this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes)
    await this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes)

    // this._logger.info(`FetchMessagesInFolder: Deep scan finished.`);
    await this._folder.updateSyncState({
      attributeFetchedMax: (from <= 1 ? recentStart : from),
      lastAttributeScanTime: Date.now(),
    });
    console.log(`🔃 🚩 ${this._folder.name} via scan through ${recentRange} and ${backScanRange} - took ${Date.now() - start}ms to update ${numChangedLabels + numChangedFlags} messages & threads`)
  }

  _shouldFetchMessages(boxStatus) {
    if (boxStatus.name !== this._folder.name) {
      throw new Error(`FetchMessagesInFolder::_shouldFetchMessages - boxStatus doesn't correspond to folder`)
    }
    if (!this._folder.isSyncComplete()) {
      return true
    }
    const {syncState} = this._folder
    return boxStatus.uidnext > syncState.fetchedmax
  }

  _shouldFetchAttributes(boxStatus) {
    if (boxStatus.name !== this._folder.name) {
      throw new Error(`FetchMessagesInFolder::_shouldFetchMessages - boxStatus doesn't correspond to folder`)
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
  async * runTask(db, imap) {
    console.log(`🔜 📂 ${this._folder.name}`)
    this._db = db;
    this._imap = imap;

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

    if (!this._shouldSyncFolder(latestBoxStatus)) {
      // Don't even attempt to issue an IMAP SELECT if there are absolutely no
      // updates
      console.log(`🔚 📂 ${this._folder.name} has no updates at all - skipping sync`)
      return;
    }

    this._box = yield this._openMailboxAndEnsureValidity();
    const shouldFetchMessages = this._shouldFetchMessages(this._box)
    const shouldFetchAttributes = this._shouldFetchAttributes(this._box)

    // Do as little work as possible
    if (shouldFetchMessages) {
      yield this._fetchNextMessageBatch()
    } else {
      console.log(`🔚 📂 ${this._folder.name} has no new messages - skipping fetch messages`)
    }
    if (shouldFetchAttributes) {
      yield this._fetchMessageAttributeChanges();
    } else {
      console.log(`🔚 📂 ${this._folder.name} has no attribute changes - skipping fetch attributes`)
    }
    console.log(`🔚 📂 ${this._folder.name} done`)
  }
}

module.exports = FetchMessagesInFolderIMAP;
