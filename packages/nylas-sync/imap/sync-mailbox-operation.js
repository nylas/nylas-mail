const _ = require('underscore');
const {processMessage} = require(`nylas-message-processor`);
const {Capabilities} = require('./connection.js');

const MessageFlagAttributes = ['id', 'CategoryUID', 'unread', 'starred']

class SyncMailboxOperation {
  constructor(category, options) {
    this._category = category;
    this._options = options;
    if (!this._category) {
      throw new Error("SyncMailboxOperation requires a category")
    }
  }

  description() {
    return `SyncMailboxOperation (${this._category.name} - ${this._category.id})\n  Options: ${JSON.stringify(this._options)}`;
  }

  _getLowerBoundUID(count) {
    return count ? Math.max(1, this._box.uidnext - count) : 1;
  }

  _recoverFromUIDInvalidity() {
    // UID invalidity means the server has asked us to delete all the UIDs for
    // this folder and start from scratch. We let a garbage collector clean up
    // actual Messages, because we may just get new UIDs pointing to the same
    // messages.
    const {Message} = this._db;
    return this._db.sequelize.transaction((transaction) =>
      Message.update({
        CategoryUID: null,
        CategoryId: null,
      }, {
        transaction: transaction,
        where: {
          CategoryId: this._category.id,
        },
      })
    )
  }

  _createAndUpdateMessages(remoteUIDAttributes, localMessageAttributes) {
    const messageAttributesMap = {};
    for (const msg of localMessageAttributes) {
      messageAttributesMap[msg.CategoryUID] = msg;
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

    console.log(` -- found ${createdUIDs.length} new messages`)
    console.log(` -- found ${changedMessages.length} flag changes`)

    return Promise.props({
      creates: this._imap.fetchMessages(createdUIDs, this._processMessage.bind(this)),
      updates: this._db.sequelize.transaction((transaction) =>
        Promise.all(changedMessages.map(m => m.save({
          fields: MessageFlagAttributes,
          transaction,
        })))
      ),
    })
  }

  _removeDeletedMessages(remoteUIDAttributes, localMessageAttributes) {
    const {Message} = this._db;

    const removedUIDs = localMessageAttributes
      .filter(msg => !remoteUIDAttributes[msg.CategoryUID])
      .map(msg => msg.CategoryUID)

    console.log(` -- found ${removedUIDs.length} messages no longer in the folder`)

    if (removedUIDs.length === 0) {
      return Promise.resolve();
    }
    return this._db.sequelize.transaction((transaction) =>
       Message.update({
         CategoryUID: null,
         CategoryId: null,
       }, {
         transaction,
         where: {
           CategoryId: this._category.id,
           CategoryUID: removedUIDs,
         },
       })
    );
  }

  _processMessage(attributes, headers, body) {
    const {Message, accountId} = this._db;

    const hash = Message.hashForHeaders(headers);
    const values = {
      hash: hash,
      rawHeaders: headers,
      rawBody: body,
      unread: !attributes.flags.includes('\\Seen'),
      starred: attributes.flags.includes('\\Flagged'),
      date: attributes.date,
      CategoryUID: attributes.uid,
      CategoryId: this._category.id,
    }
    Message.find({where: {hash}}).then((existing) => {
      if (existing) {
        Object.assign(existing, values);
        return existing.save();
      }
      return Message.create(values)
      .then((created) => processMessage({accountId, messageId: created.id}))
    })
  }

  _openMailboxAndEnsureValidity() {
    return this._imap.openBox(this._category.name, true).then((box) => {
      this._box = box;

      if (box.persistentUIDs === false) {
        throw new Error("Mailbox does not support persistentUIDs.")
      }
      if (box.uidvalidity !== this._category.syncState.uidvalidity) {
        return this._recoverFromUIDInvalidity();
      }
      return Promise.resolve();
    })
  }

  _fetchUnseenMessages() {
    const savedSyncState = this._category.syncState;
    const boxSyncState = {
      uidnext: this._box.uidnext,
      uidvalidity: this._box.uidvalidity,
    }

    const {limit} = this._options;
    let range = `${this._getLowerBoundUID(limit)}:*`;

    console.log(` - fetching unseen messages ${range}`)

    if (savedSyncState.uidnext) {
      if (savedSyncState.uidnext === boxSyncState.uidnext) {
        console.log(" --- uidnext matches, nothing more to fetch")
        return Promise.resolve();
      }
      range = `${savedSyncState.uidnext}:*`
    }

    return this._imap.fetch(range, this._processMessage.bind(this)).then(() => {
      console.log(` - finished fetching unseen messages`);
      return this.updateCategorySyncState({
        uidnext: boxSyncState.uidnext,
        uidvalidity: boxSyncState.uidvalidity,
        timeFetchedUnseen: Date.now(),
      });
    });
  }

  _fetchChangesToMessages() {
    const {highestmodseq, timeDeepScan} = this._category.syncState;
    const nextHighestmodseq = this._box.highestmodseq;

    const {Message} = this._db;
    const {limit} = this._options;
    const range = `${this._getLowerBoundUID(limit)}:*`;

    console.log(` - fetching changes to messages ${range}`)

    const shouldRunDeepScan = Date.now() - (timeDeepScan || 0) > this._options.deepFolderScan

    if (shouldRunDeepScan) {
      return this._imap.fetchUIDAttributes(range).then((remoteUIDAttributes) =>
        Message.findAll({
          where: {CategoryId: this._category.id},
          attributes: MessageFlagAttributes,
        }).then((localMessageAttributes) =>
          Promise.props({
            upserts: this._createAndUpdateMessages(remoteUIDAttributes, localMessageAttributes),
            deletes: this._removeDeletedMessages(remoteUIDAttributes, localMessageAttributes),
          })
        ).then(() => {
          return this.updateCategorySyncState({
            highestmodseq: nextHighestmodseq,
            timeDeepScan: Date.now(),
            timeShallowScan: Date.now(),
          });
        })
      );
    }

    let shallowFetch = null;

    if (this._imap.serverSupports(Capabilities.Condstore)) {
      if (nextHighestmodseq === highestmodseq) {
        console.log(" --- highestmodseq matches, nothing more to fetch")
        return Promise.resolve();
      }
      shallowFetch = this._imap.fetchUIDAttributes(range, {changedsince: highestmodseq});
    } else {
      shallowFetch = this._imap.fetchUIDAttributes(`${this._getLowerBoundUID(1000)}:*`);
    }

    return shallowFetch.then((remoteUIDAttributes) =>
      Message.findAll({
        where: {CategoryId: this._category.id},
        attributes: MessageFlagAttributes,
      }).then((localMessageAttributes) =>
        this._createAndUpdateMessages(remoteUIDAttributes, localMessageAttributes)
      ).then(() => {
        return this.updateCategorySyncState({
          highestmodseq: nextHighestmodseq,
          timeShallowScan: Date.now(),
        });
      })
    )
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

    return this._openMailboxAndEnsureValidity()
    .then(() =>
      this._fetchUnseenMessages()
    ).then(() =>
      this._fetchChangesToMessages()
    )
  }
}

module.exports = SyncMailboxOperation;
