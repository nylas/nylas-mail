const Imap = require('imap');
const EventEmitter = require('events');

const Capabilities = {
  Gmail: 'X-GM-EXT-1',
  Quota: 'QUOTA',
  UIDPlus: 'UIDPLUS',
  Condstore: 'CONDSTORE',
  Search: 'ESEARCH',
  Sort: 'SORT',
}

class IMAPConnection extends EventEmitter {
  constructor(db, settings) {
    super();

    this._db = db;
    this._queue = [];
    this._current = null;
    this._capabilities = [];
    this._imap = Promise.promisifyAll(new Imap(settings));

    this._imap.once('ready', () => {
      for (const key of Object.keys(Capabilities)) {
        const val = Capabilities[key];
        if (this._imap.serverSupports(val)) {
          this._capabilities.push(val);
        }
      }
      this.emit('ready');
    });

    this._imap.once('error', (err) => {
      console.log(err);
    });

    this._imap.once('end', () => {
      console.log('Connection ended');
    });

    this._imap.on('alert', (msg) => {
      console.log(`IMAP SERVER SAYS: ${msg}`)
    })

    // Emitted when new mail arrives in the currently open mailbox.
    // Fix https://github.com/mscdex/node-imap/issues/445
    let lastMailEventBox = null;
    this._imap.on('mail', () => {
      if (lastMailEventBox === this._imap._box.name) {
        this.emit('mail');
      }
      lastMailEventBox = this._imap._box.name
    });

    // Emitted if the UID validity value for the currently open mailbox
    // changes during the current session.
    this._imap.on('uidvalidity', () => this.emit('uidvalidity'))

    // Emitted when message metadata (e.g. flags) changes externally.
    this._imap.on('update', () => this.emit('update'))

    this._imap.connect();
  }

  openBox(box) {
    return this._imap.openBoxAsync(box, true);
  }

  getBoxes() {
    return this._imap.getBoxesAsync();
  }

  fetch(range, messageReadyCallback) {
    return new Promise((resolve, reject) => {
      const f = this._imap.fetch(range, {
        bodies: ['HEADER', 'TEXT'],
      });
      f.on('message', (msg, uid) =>
        this._receiveMessage(msg, uid, messageReadyCallback));
      f.once('error', reject);
      f.once('end', resolve);
    });
  }

  fetchMessages(uids, messageReadyCallback) {
    if (uids.length === 0) {
      return Promise.resolve();
    }
    return this.fetch(uids, messageReadyCallback);
  }

  fetchUIDAttributes(range) {
    return new Promise((resolve, reject) => {
      const latestUIDAttributes = {};
      const f = this._imap.fetch(range, {});
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

  _receiveMessage(msg, uid, callback) {
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
      callback(attributes, headers, body, uid);
    });
  }

  runOperation(operation) {
    return new Promise((resolve, reject) => {
      this._queue.push({operation, resolve, reject});
      if (this._imap.state === 'authenticated' && !this._current) {
        this.processNextOperation();
      }
    });
  }

  processNextOperation() {
    if (this._current) { return; }

    this._current = this._queue.shift();

    if (!this._current) {
      this.emit('queue-empty');
      return;
    }

    const {operation, resolve, reject} = this._current;

    console.log(`Starting task ${operation.description()}`)
    const result = operation.run(this._db, this);
    if (result instanceof Promise === false) {
      throw new Error(`Expected ${operation.constructor.name} to return promise.`);
    }
    result.catch((err) => {
      this._current = null;
      console.error(err);
      reject();
    })
    .then(() => {
      this._current = null;
      console.log(`Finished task ${operation.description()}`)
      resolve();
    })
    .finally(() => {
      this.processNextOperation();
    });
  }
}

module.exports = IMAPConnection
