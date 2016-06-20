const _ = require('underscore');
const { processMessage } = require(`${__base}/message-processor`)


class SyncMailboxOperation {
  constructor(category) {
    this._category = category;
    if (!this._category) {
      throw new Error("SyncMailboxOperation requires a category")
    }
  }

  description() {
    return `SyncMailboxOperation (${this._category.name} - ${this._category.id})`;
  }

  _unlinkAllMessages() {
    const {MessageUID} = this._db;
    return MessageUID.destroy({
      where: {
        CategoryId: this._category.id,
      },
    })
  }

  _removeDeletedMessageUIDs(removedUIDs) {
    const {MessageUID} = this._db;

    if (removedUIDs.length === 0) {
      return Promise.resolve();
    }
    return this._db.sequelize.transaction((transaction) =>
       MessageUID.destroy({where: {uid: removedUIDs}}, {transaction})
    );
  }

  _deltasInUIDsAndFlags(latestUIDAttributes, knownUIDs) {
    const removedUIDs = [];
    const neededUIDs = [];

    for (const known of knownUIDs) {
      if (!latestUIDAttributes[known.uid]) {
        removedUIDs.push(known.uid);
        continue;
      }
      if (!_.isEqual(latestUIDAttributes[known.uid].flags, known.flags)) {
        known.flags = latestUIDAttributes[known.uid].flags;
        neededUIDs.push(known.uid);
      }

      // delete entries from the attributes hash as we go. At the end,
      // remaining keys will be the ones that we don't have locally.
      delete latestUIDAttributes[known.uid];
    }

    return {
      neededUIDs: neededUIDs.concat(Object.keys(latestUIDAttributes)),
      removedUIDs: removedUIDs,
    };
  }

  _processMessage(attributes, headers, body) {
    const {Message, MessageUID, accountId} = this._db;

    const hash = Message.hashForHeaders(headers);

    MessageUID.create({
      messageHash: hash,
      CategoryId: this._category.id,
      flags: attributes.flags,
      uid: attributes.uid,
    });
    return processMessage({accountId, attributes, headers, body, hash})
  }

  _openMailboxAndCheckValidity() {
    return this._imap.openBox(this._category.name, true).then((box) => {
      this._box = box;

      if (box.persistentUIDs === false) {
        throw new Error("Mailbox does not support persistentUIDs.")
      }
      if (box.uidvalidity !== this._category.syncState.uidvalidity) {
        return this._unlinkAllMessages();
      }
      return Promise.resolve();
    })
  }

  _fetchUnseenMessages() {
    const savedSyncState = this._category.syncState;
    const currentSyncState = {
      uidnext: this._box.uidnext,
      uidvalidity: this._box.uidvalidity,
    }

    console.log(" - fetching unseen messages")

    let fetchRange = `1:*`;
    if (savedSyncState.uidnext) {
      if (savedSyncState.uidnext === currentSyncState.uidnext) {
        console.log(" --- nothing more to fetch")
        return Promise.resolve();
      }
      fetchRange = `${savedSyncState.uidnext}:*`
    }

    return this._imap.fetch(fetchRange, this._processMessage.bind(this)).then(() => {
      this._category.syncState = currentSyncState;
      return this._category.save();
    });
  }

  _fetchChangesToMessages() {
    const {MessageUID} = this._db;

    console.log(" - fetching changes to messages")

    return this._imap.fetchUIDAttributes(`1:*`).then((latestUIDAttributes) => {
      return MessageUID.findAll({where: {CategoryId: this._category.id}}).then((knownUIDs) => {
        const {removedUIDs, neededUIDs} = this._deltasInUIDsAndFlags(latestUIDAttributes, knownUIDs);

        console.log(` - found changed / new UIDs: ${neededUIDs.join(', ')}`)
        console.log(` - found removed UIDs: ${removedUIDs.join(', ')}`)

        return Promise.props({
          deletes: this._removeDeletedMessageUIDs(removedUIDs),
          changes: this._imap.fetchMessages(neededUIDs, this._processMessage.bind(this)),
        });
      });
    });
  }

  run(db, imap) {
    this._db = db;
    this._imap = imap;

    return this._openMailboxAndCheckValidity()
    .then(() =>
      this._fetchUnseenMessages()
    ).then(() =>
      this._fetchChangesToMessages()
    )
  }
}

module.exports = SyncMailboxOperation;
