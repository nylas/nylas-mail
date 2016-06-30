const _ = require('underscore');
const Imap = require('imap');

const {IMAPConnection, PubsubConnector} = require('nylas-core');
const {Capabilities} = IMAPConnection;

const MessageFlagAttributes = ['id', 'categoryImapUID', 'unread', 'starred']

class FetchMessagesInCategory {
  constructor(category, options) {
    this._imap = null
    this._box = null
    this._db = null
    this._category = category;
    this._options = options;
    if (!this._category) {
      throw new NylasError("FetchMessagesInCategory requires a category")
    }
  }

  description() {
    return `FetchMessagesInCategory (${this._category.name} - ${this._category.id})\n  Options: ${JSON.stringify(this._options)}`;
  }

  _getLowerBoundUID(count) {
    return count ? Math.max(1, this._box.uidnext - count) : 1;
  }

  _recoverFromUIDInvalidity() {
    // UID invalidity means the server has asked us to delete all the UIDs for
    // this folder and start from scratch. Instead of deleting all the messages,
    // we just remove the category ID and UID. We may re-assign the same message
    // the same UID. Otherwise they're eventually garbage collected.
    const {Message} = this._db;
    return this._db.sequelize.transaction((transaction) =>
      Message.update({
        categoryImapUID: null,
        categoryId: null,
      }, {
        transaction: transaction,
        where: {
          categoryId: this._category.id,
        },
      })
    )
  }

  _updateMessageAttributes(remoteUIDAttributes, localMessageAttributes) {
    const messageAttributesMap = {};
    for (const msg of localMessageAttributes) {
      messageAttributesMap[msg.categoryImapUID] = msg;
    }

    const createdUIDs = [];
    const changedMessages = [];

    Object.keys(remoteUIDAttributes).forEach((uid) => {
      const msg = messageAttributesMap[uid];
      const flags = remoteUIDAttributes[uid].flags;

      if (!msg) {
        createdUIDs.push(uid);
        return;
      }

      const unread = !flags.includes('\\Seen');
      const starred = flags.includes('\\Flagged');

      if (msg.unread !== unread || msg.starred !== starred) {
        msg.unread = unread;
        msg.starred = starred;
        changedMessages.push(msg);
      }
    })

    console.log(` --- found ${changedMessages.length || 'no'} flag changes`)
    if (createdUIDs.length > 0) {
      console.log(` --- found ${createdUIDs.length} new messages. These will not be processed because we assume that they will be assigned uid = uidnext, and will be picked up in the next sync when we discover unseen messages.`)
    }

    return this._db.sequelize.transaction((transaction) =>
      Promise.all(changedMessages.map(m => m.save({
        fields: MessageFlagAttributes,
        transaction,
      })))
    );
  }

  _removeDeletedMessages(remoteUIDAttributes, localMessageAttributes) {
    const {Message} = this._db;

    const removedUIDs = localMessageAttributes
      .filter(msg => !remoteUIDAttributes[msg.categoryImapUID])
      .map(msg => msg.categoryImapUID)

    console.log(` --- found ${removedUIDs.length} messages no longer in the folder`)

    if (removedUIDs.length === 0) {
      return Promise.resolve();
    }
    return this._db.sequelize.transaction((transaction) =>
       Message.update({
         categoryImapUID: null,
         categoryId: null,
       }, {
         transaction,
         where: {
           categoryId: this._category.id,
           categoryImapUID: removedUIDs,
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
          desired.push({id: part.partID, mimetype});
        }
      }
    }

    if (desired.length === 0) {
      console.warn(`Could not find good part. Options are: ${available.join(', ')}`)
    }

    return desired;
  }

  _fetchMessagesAndQueueForProcessing(range) {
    const uidsByPart = {};

    const $structs = this._box.fetch(range, {struct: true})
    $structs.subscribe(({attributes}) => {
      const desiredParts = this._getDesiredMIMEParts(attributes.struct);
      if (desiredParts.length === 0) {
        return;
      }
      const key = JSON.stringify(desiredParts);
      console.log(key);
      uidsByPart[key] = uidsByPart[key] || [];
      uidsByPart[key].push(attributes.uid);
    });

    return $structs.toPromise().then(() => {
      return Promise.each(Object.keys(uidsByPart), (key) => {
        const uids = uidsByPart[key];
        const desiredParts = JSON.parse(key);
        const bodies = ['HEADER'].concat(desiredParts.map(p => p.id));
        console.log(`Fetching parts ${key} for ${uids.length} messages`)

        // note: the order of UIDs in the array doesn't matter, Gmail always
        // returns them in ascending (oldest => newest) order.

        const $body = this._box.fetch(uids, {bodies, struct: true})
        $body.subscribe((msg) => {
          console.log(`Fetched message ${msg.attributes.uid}`)
          msg.body = {};
          for (const {id, mimetype} of desiredParts) {
            msg.body[mimetype] = msg.parts[id];
          }
          this._processMessage(msg);
        });

        return $body.toPromise();
      })
    });
  }

  _createFilesFromStruct({message, struct}) {
    const {File} = this._db
    for (const part of struct) {
      if (part.constructor === Array) {
        this._createFilesFromStruct({message, struct: part})
      } else if (part.disposition) {
        let filename = null
        if (part.disposition.params) {
          filename = part.disposition.params.filename
        }
        File.create({
          filename: filename,
          contentId: part.partID,
          contentType: `${part.type}/${part.subtype}`,
          accountId: this._db.accountId,
          size: part.size,
        })
        .then((file) => {
          file.setMessage(message)
          message.addFile(file)
        })
      }
    }
  }

  _processMessage({attributes, headers, body}) {
    const {Message, accountId} = this._db;
    const hash = Message.hashForHeaders(headers);

    const parsedHeaders = Imap.parseHeader(headers);
    for (const key of ['x-gm-thrid', 'x-gm-msgid', 'x-gm-labels']) {
      parsedHeaders[key] = attributes[key];
    }

    const values = {
      hash: hash,
      accountId: this._db.accountId,
      body: body['text/html'] || body['text/plain'] || body['application/pgp-encrypted'] || '',
      snippet: body['text/plain'] || null,
      unread: !attributes.flags.includes('\\Seen'),
      starred: attributes.flags.includes('\\Flagged'),
      date: attributes.date,
      categoryImapUID: attributes.uid,
      categoryId: this._category.id,
      headers: parsedHeaders,
      headerMessageId: parsedHeaders['message-id'][0],
      subject: parsedHeaders.subject[0],
    }

    Message.find({where: {hash}}).then((existing) => {
      if (existing) {
        Object.assign(existing, values);
        existing.save();
        return;
      }

      Message.create(values).then((created) => {
        this._createFilesFromStruct({message: created, struct: attributes.struct})
        PubsubConnector.queueProcessMessage({accountId, messageId: created.id});
      })
    })

    return null;
  }

  _openMailboxAndEnsureValidity() {
    return this._imap.openBox(this._category.name)
    .then((box) => {
      if (box.persistentUIDs === false) {
        return Promise.reject(new NylasError("Mailbox does not support persistentUIDs."))
      }
      if (box.uidvalidity !== this._category.syncState.uidvalidity) {
        return this._recoverFromUIDInvalidity()
        .then(() => Promise.resolve(box))
      }
      return Promise.resolve(box);
    })
  }

  _fetchUnsyncedMessages() {
    const savedSyncState = this._category.syncState;
    const isFirstSync = !savedSyncState.fetchedmax;
    const boxUidnext = this._box.uidnext;
    const boxUidvalidity = this._box.uidvalidity;

    const desiredRanges = [];

    console.log(` - Fetching messages. Currently have range: ${savedSyncState.fetchedmin}:${savedSyncState.fetchedmax}`)

    // Todo: In the future, this is where logic should go that limits
    // sync based on number of messages / age of messages.

    if (isFirstSync) {
      const lowerbound = Math.max(1, boxUidnext - 150);
      desiredRanges.push({min: lowerbound, max: boxUidnext})
    } else {
      if (savedSyncState.fetchedmax < boxUidnext) {
        desiredRanges.push({min: savedSyncState.fetchedmax, max: boxUidnext})
      } else {
        console.log(" --- fetchedmax == uidnext, nothing more recent to fetch.")
      }
      if (savedSyncState.fetchedmin > 1) {
        const lowerbound = Math.max(1, savedSyncState.fetchedmin - 1000);
        desiredRanges.push({min: lowerbound, max: savedSyncState.fetchedmin})
      } else {
        console.log(" --- fetchedmin == 1, nothing older to fetch.")
      }
    }

    return Promise.each(desiredRanges, ({min, max}) => {
      console.log(` --- fetching range: ${min}:${max}`);

      return this._fetchMessagesAndQueueForProcessing(`${min}:${max}`).then(() => {
        const {fetchedmin, fetchedmax} = this._category.syncState;
        return this.updateCategorySyncState({
          fetchedmin: fetchedmin ? Math.min(fetchedmin, min) : min,
          fetchedmax: fetchedmax ? Math.max(fetchedmax, max) : max,
          uidvalidity: boxUidvalidity,
          timeFetchedUnseen: Date.now(),
        });
      })
    }).then(() => {
      console.log(` - Fetching messages finished`);
    });
  }

  _runScan() {
    const {fetchedmin, fetchedmax} = this._category.syncState;
    if (!fetchedmin || !fetchedmax) {
      throw new Error("Unseen messages must be fetched at least once before the first update/delete scan.")
    }
    return this._shouldRunDeepScan() ? this._runDeepScan() : this._runShallowScan()
  }

  _shouldRunDeepScan() {
    const {timeDeepScan} = this._category.syncState;
    return Date.now() - (timeDeepScan || 0) > this._options.deepFolderScan;
  }

  _runShallowScan() {
    const {highestmodseq} = this._category.syncState;
    const nextHighestmodseq = this._box.highestmodseq;

    let shallowFetch = null;

    if (this._imap.serverSupports(Capabilities.Condstore)) {
      console.log(` - Shallow attribute scan (using CONDSTORE)`)
      if (nextHighestmodseq === highestmodseq) {
        console.log(" --- highestmodseq matches, nothing more to fetch")
        return Promise.resolve();
      }
      shallowFetch = this._box.fetchUIDAttributes(`1:*`, {changedsince: highestmodseq});
    } else {
      const range = `${this._getLowerBoundUID(1000)}:*`;
      console.log(` - Shallow attribute scan (using range: ${range})`)
      shallowFetch = this._box.fetchUIDAttributes(range);
    }

    return shallowFetch
    .then((remoteUIDAttributes) => (
      this._db.Message.findAll({
        where: {categoryId: this._category.id},
        attributes: MessageFlagAttributes,
      })
      .then((localMessageAttributes) => (
        this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes)
      ))
      .then(() => {
        console.log(` - finished fetching changes to messages`);
        return this.updateCategorySyncState({
          highestmodseq: nextHighestmodseq,
          timeShallowScan: Date.now(),
        })
      })
    ))
  }

  _runDeepScan() {
    const {Message} = this._db;
    const {fetchedmin, fetchedmax} = this._category.syncState;
    const range = `${fetchedmin}:${fetchedmax}`;

    console.log(` - Deep attribute scan: fetching attributes in range: ${range}`)

    return this._box.fetchUIDAttributes(range)
    .then((remoteUIDAttributes) => {
      return Message.findAll({
        where: {categoryId: this._category.id},
        attributes: MessageFlagAttributes,
      })
      .then((localMessageAttributes) => (
        Promise.props({
          updates: this._updateMessageAttributes(remoteUIDAttributes, localMessageAttributes),
          deletes: this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes),
        })
      ))
      .then(() => {
        console.log(` - Deep scan finished.`);
        return this.updateCategorySyncState({
          highestmodseq: this._box.highestmodseq,
          timeDeepScan: Date.now(),
          timeShallowScan: Date.now(),
        })
      })
    });
  }

  updateCategorySyncState(newState) {
    if (_.isMatch(this._category.syncState, newState)) {
      return Promise.resolve();
    }
    this._category.syncState = Object.assign(this._category.syncState, newState);
    return this._category.save();
  }

  run(db, imap) {
    this._db = db;
    this._imap = imap;

    return this._openMailboxAndEnsureValidity().then((box) => {
      this._box = box
      return this._fetchUnsyncedMessages().then(() =>
        this._runScan()
      )
    })
  }
}

module.exports = FetchMessagesInCategory;
