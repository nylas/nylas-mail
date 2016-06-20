class ScanUIDsOperation {
  constructor(category) {
    this._category = category;
  }

  description() {
    return `ScanUIDsOperation (${this._category.name})`;
  }

  _fetchUIDAttributes(imap, range) {
    return new Promise((resolve, reject) => {
      const latestUIDAttributes = {};
      const f = imap.fetch(range, {});
      f.on('message', (msg, uid) => {
        msg.on('attributes', (attrs) => {
          latestUIDAttributes[uid] = attrs;
        })
      });
      f.once('error', reject);
      f.once('end', () => {
        resolve(latestUIDAttributes);
      });
    });
  }

  _fetchMessages(uids) {
    if (uids.length === 0) {
      return Promise.resolve();
    }
    console.log(`TODO! NEED TO FETCH UIDS ${uids.join(', ')}`)
    return Promise.resolve();
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
      if (latestUIDAttributes[known.uid].flags !== known.flags) {
        known.flags = latestUIDAttributes[known.uid].flags;
        neededUIDs.push(known.uid);
      }
      delete latestUIDAttributes[known.uid];
    }

    return {
      neededUIDs: neededUIDs.concat(Object.keys(latestUIDAttributes)),
      removedUIDs: removedUIDs,
    };
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
    const {MessageUID} = db;

    return imap.openBoxAsync(this._category.name, true).then(() => {
      return this._fetchUIDAttributes(imap, `1:*`).then((latestUIDAttributes) => {
        return MessageUID.findAll({CategoryId: this._category.id}).then((knownUIDs) => {
          const {removedUIDs, neededUIDs} = this._deltasInUIDsAndFlags(latestUIDAttributes, knownUIDs);

          return Promise.props({
            deletes: this._removeDeletedMessageUIDs(removedUIDs),
            changes: this._fetchMessages(neededUIDs),
          });
        });
      });
    });
  }
}

module.exports = ScanUIDsOperation;
