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
    this._imap = Promise.promisifyAll(new Imap({
      host: settings.imap_host,
      port: settings.imap_port,
      user: settings.imap_username,
      password: settings.imap_password,
      tls: settings.ssl_required,
    }));

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
  }

  serverSupports(cap) {
    this._imap.serverSupports(cap);
  }

  connect() {
    if (!this._connectPromise) {
      this._connectPromise = new Promise((resolve, reject) => {
        this._imap.once('ready', resolve);
        this._imap.once('error', reject);
        this._imap.connect();
      });
    }
    return this._connectPromise;
  }

  end() {
    this._queue = [];
    this._imap.end();
  }

  openBox(box) {
    return this._imap.openBoxAsync(box, true);
  }

  getBoxes() {
    return this._imap.getBoxesAsync();
  }

  fetch(range, messageCallback) {
    return new Promise((resolve, reject) => {
      const f = this._imap.fetch(range, {
        bodies: ['HEADER', 'TEXT'],
      });
      f.on('message', (msg) =>
        this._receiveMessage(msg, messageCallback)
      )
      f.once('error', reject);
      f.once('end', resolve);
    });
  }

  fetchMessages(uids, messageCallback) {
    if (uids.length === 0) {
      return Promise.resolve();
    }
    return this.fetch(uids, messageCallback);
  }

  fetchUIDAttributes(range) {
    return new Promise((resolve, reject) => {
      const latestUIDAttributes = {};
      const f = this._imap.fetch(range, {});
      f.on('message', (msg) => {
        msg.on('attributes', (attrs) => {
          latestUIDAttributes[attrs.uid] = attrs;
        })
      });
      f.once('error', reject);
      f.once('end', () => {
        resolve(latestUIDAttributes);
      });
    });
  }

  _receiveMessage(msg, callback) {
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
      callback(attributes, headers, body);
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

IMAPConnection.Capabilities = Capabilities;

module.exports = IMAPConnection
