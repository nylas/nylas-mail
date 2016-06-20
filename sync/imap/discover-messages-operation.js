class SyncMailboxOperation {
  constructor(category) {
    this._category = category;
    if (!this._category) {
      throw new Error("SyncMailboxOperation requires a category")
    }
  }

  description() {
    return `SyncMailboxOperation (${this._category.name})`;
  }

  _fetch(imap, range) {
    return new Promise((resolve, reject) => {
      const f = imap.fetch(range, {
        bodies: ['HEADER', 'TEXT'],
      });
      f.on('message', (msg, uid) => this._receiveMessage(msg, uid));
      f.once('error', reject);
      f.once('end', resolve);
    });
  }

  _unlinkAllMessages() {
    const {MessageUID} = this._db;
    return MessageUID.destroy({
      where: {
        CategoryId: this._category.id,
      },
    })
  }

  _receiveMessage(msg, uid) {
    let attributes = null;
    let body = null;
    let headers = null;

    msg.on('attributes', (attrs) => {
      attributes = attrs;
    });
    msg.on('body', (stream, info) => {
      const chunks = [];

      stream.on('data', (chunk) => {
        chunks.push(chunk);
      });
      stream.once('end', () => {
        const full = Buffer.concat(chunks).toString('utf8');
        if (info.which === 'HEADER') {
          headers = full;
        }
        if (info.which === 'TEXT') {
          body = full;
        }
      });
    });
    msg.once('end', () => {
      this._processMessage(attributes, headers, body, uid);
    });
  }

  _processMessage(attributes, headers, body) {
    console.log(attributes);
    const {Message, MessageUID} = this._db;

    return Message.create({
      unread: attributes.flags.includes('\\Unseen'),
      starred: attributes.flags.includes('\\Flagged'),
      date: attributes.date,
      headers: headers,
      body: body,
    }).then((model) => {
      return MessageUID.create({
        MessageId: model.id,
        CategoryId: this._category.id,
        flags: attributes.flags,
        uid: attributes.uid,
      });
    });
  }

  // _flushProcessedMessages() {
  //   return sequelize.transaction((transaction) => {
  //     return Promise.props({
  //       msgs: Message.bulkCreate(this._processedMessages, {transaction})
  //       uids: MessageUID.bulkCreate(this._processedMessageUIDs, {transaction})
  //     })
  //   }).then(() => {
  //     this._processedMessages = [];
  //     this._processedMessageUIDs = [];
  //   });
  // }

  run(db, imap) {
    this._db = db;

    return imap.openBoxAsync(this._category.name, true).then((box) => {
      this._box = box;

      if (box.persistentUIDs === false) {
        throw new Error("Mailbox does not support persistentUIDs.")
      }
      if (box.uidvalidity !== this._category.syncState.uidvalidity) {
        return this._unlinkAllMessages();
      }
      return Promise.resolve();
    })
    .then(() => {
      const savedSyncState = this._category.syncState;
      const currentSyncState = {
        uidnext: this._box.uidnext,
        uidvalidity: this._box.uidvalidity,
      }

      let fetchRange = `1:*`;
      if (savedSyncState.uidnext) {
        if (savedSyncState.uidnext === currentSyncState.uidnext) {
          return Promise.resolve();
        }
        fetchRange = `${savedSyncState.uidnext}:*`
      }

      return this._fetch(imap, fetchRange).then(() => {
        this._category.syncState = currentSyncState;
        return this._category.save();
      });
    })
  }
}

module.exports = SyncMailboxOperation;
