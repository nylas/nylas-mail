const {inspect} = require('util');
const Promise = require('bluebird');
const Imap = require('imap');

const State = {
  Closed: 'closed',
  Connecting: 'connecting',
  Open: 'open',
}

const Capabilities = {
  Gmail: 'X-GM-EXT-1',
  Quota: 'QUOTA',
  UIDPlus: 'UIDPLUS',
  Condstore: 'CONDSTORE',
  Search: 'ESEARCH',
  Sort: 'SORT',
}

class SyncIMAPConnection {
  constructor(settings) {
    this._queue = [];
    this._current = null;
    this._state = State.Connecting;
    this._capabilities = [];

    this._imap = Promise.promisifyAll(new Imap(settings));

    this._imap.once('ready', () => {
      this._state = State.Open;
      for (const key of Object.keys(Capabilities)) {
        const val = Capabilities[key];
        if (this._imap.serverSupports(val)) {
          this._capabilities.push(val);
        }
      }
      this.processNextOperation();
    });
    this._imap.once('error', (err) => {
      console.log(err);
    });
    this._imap.once('end', () => {
      this._state = State.Closed;
      console.log('Connection ended');
    });
    this._imap.connect();
  }

  queueOperation(op) {
    this._queue.push(op);
    if (this._state === State.Open && !this._current) {
      this.processNextOperation();
    }
  }

  processNextOperation() {
    if (this._current) { return; }

    this._current = this._queue.shift();

    if (this._current) {
      console.log(`Starting task ${this._current.constructor.name}`)

      const result = this._current.run(this._imap);
      if (result instanceof Promise === false) {
        throw new Error(`processNextOperation: Expected ${this._current.constructor.name} to return promise.`);
      }
      result.catch((err) => {
        this._current = null;
        console.error(err);
      });
      result.then(() => {
        console.log(`Finished task ${this._current.constructor.name}`)
        this._current = null;
        this.processNextOperation();
      });
    }
  }
}

class SyncMailboxOperation {
  constructor(db, {role} = {}) {
    this._db = db;
    this._category = null;
    this._box = null;
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
        categoryId: this._category.id,
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
    msg.on('body', (stream, type) => {
      const chunks = [];
      stream.on('data', (chunk) => {
        chunks.push(chunk);
      });
      stream.once('end', () => {
        const full = Buffer.concat(chunks).toString('utf8');
        if (type === 'TEXT') {
          body = full;
        }
        if (type === 'HEADERS') {
          headers = full;
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
      body: body,
    }).then((model) => {
      return MessageUID.create({
        MessageId: model.id,
        CategoryId: this._category.id,
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

  run(imap) {
    const {Category} = this._db;

    return Promise.props({
      box: imap.openBoxAsync('INBOX', true),
      category: Category.find({name: 'INBOX'}),
    })
    .then(({category, box}) => {
      if (this.box.persistentUIDs === false) {
        throw new Error("Mailbox does not support persistentUIDs.")
      }

      this._category = category;
      this._box = box;

      if (box.uidvalidity !== category.syncState.uidvalidity) {
        return this._unlinkAllMessages();
      }
      return Promise.resolve();
    })
    .then(() => {
      const lastUIDNext = this._category.syncState.uidnext;
      const currentUIDNext = this._box.uidnext

      if (lastUIDNext) {
        if (lastUIDNext === currentUIDNext) {
          return Promise.resolve();
        }

        // just request mail >= UIDNext
        return this._fetch(imap, `${lastUIDNext}:*`);
      }
      return this._fetch(imap, `1:*`);
    });
  }
}

class RefreshMailboxesOperation {
  constructor(db) {
    this._db = db;
  }

  _roleForMailbox(box) {
    for (const attrib of (box.attribs || [])) {
      const role = {
        '\\Sent': 'sent',
        '\\Drafts': 'drafts',
        '\\Junk': 'junk',
        '\\Flagged': 'flagged',
      }[attrib];
      if (role) {
        return role;
      }
    }
    return null;
  }

  _updateCategoriesWithBoxes(categories, boxes) {
    const {Category} = this._db;

    const stack = [];
    const created = [];
    const next = [];

    Object.keys(boxes).forEach((name) => {
      stack.push([name, boxes[name]]);
    });

    while (stack.length > 0) {
      const [name, box] = stack.pop();
      if (box.children) {
        Object.keys(box.children).forEach((subname) => {
          stack.push([`${name}/${subname}`, box.children[subname]]);
        });
      }

      let category = categories.find((cat) => cat.name === name);
      if (!category) {
        category = Category.build({
          name: name,
          role: this._roleForMailbox(box),
        });
        created.push(category);
      }
      next.push(category);
    }

    // Todo: decide whether these are renames or deletes
    const deleted = categories.filter(cat => !next.includes(cat));

    return {next, created, deleted};
  }

  run(imap) {
    return imap.getBoxesAsync().then((boxes) => {
      const {Category, sequelize} = this._db;

      return sequelize.transaction((transaction) => {
        return Category.findAll({transaction}).then((categories) => {
          const {created, deleted} = this._updateCategoriesWithBoxes(categories, boxes);

          let promises = [Promise.resolve()]
          promises = promises.concat(created.map(cat => cat.save({transaction})))
          promises = promises.concat(deleted.map(cat => cat.destroy({transaction})))
          return Promise.all(promises)
        });
      });
    });
  }
}

class SyncWorker {
  constructor(account, db) {
    this._db = db
    this._conns = []

    const main = new SyncIMAPConnection({
      user: 'inboxapptest1@fastmail.fm',
      password: 'trar2e',
      host: 'mail.messagingengine.com',
      port: 993,
      tls: true,
    })
    main.queueOperation(new RefreshMailboxesOperation(db));
    main.queueOperation(new SyncMailboxOperation(db, {
      role: 'inbox',
    }));
    this._conns.push(main);
  }
}

module.exports = SyncWorker;
